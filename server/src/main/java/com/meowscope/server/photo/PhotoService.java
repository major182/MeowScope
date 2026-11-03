package com.meowscope.server.photo;

import com.meowscope.server.common.error.ApiException;
import com.meowscope.server.common.error.ErrorCode;
import com.meowscope.server.household.HouseholdAccess;
import java.io.IOException;
import java.io.InputStream;
import java.util.UUID;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;

/**
 * 写真の送信と取得（API 設計書 6章、NF-SC-08：画像のみ、上限 5MB）。
 *
 * <p>写真の情報（どの記録の何枚目か）は同期で先に届く。ここでは、その行がある写真の本体だけを受け取る。
 * 自分のおうちの写真でなければ、あるかどうかも教えずに 404 を返す（NF-SC-04）。
 */
@Service
public class PhotoService {

    /** 1枚の上限（5MB）。端末は長辺 1600px 程度に縮めて送るので、ふつうは 500KB 前後になる。 */
    static final int MAX_BYTES = 5 * 1024 * 1024;

    private final JdbcClient jdbc;
    private final HouseholdAccess access;
    private final PhotoStorage storage;

    PhotoService(JdbcClient jdbc, HouseholdAccess access, PhotoStorage storage) {
        this.jdbc = jdbc;
        this.access = access;
        this.storage = storage;
    }

    private record PhotoRow(UUID householdId, String filePath) {
    }

    private PhotoRow find(UUID userId, UUID photoId) {
        PhotoRow row = jdbc.sql("""
                SELECT c.household_id, p.file_path FROM record_photos p
                JOIN records r ON r.id = p.record_id JOIN cats c ON c.id = r.cat_id
                WHERE p.id = :id AND p.deleted_at IS NULL
                """).param("id", photoId).query(PhotoRow.class).optional()
                .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND));
        if (!access.isMember(userId, row.householdId())) {
            throw new ApiException(ErrorCode.NOT_FOUND);
        }
        return row;
    }

    void upload(UUID userId, UUID photoId, InputStream body) throws IOException {
        PhotoRow row = find(userId, photoId);
        // 上限より1バイトだけ多く読み、超えたかどうかを確かめる（全部をメモリーに読まない）
        byte[] bytes = body.readNBytes(MAX_BYTES + 1);
        if (bytes.length > MAX_BYTES) {
            throw new ApiException(ErrorCode.PAYLOAD_TOO_LARGE);
        }
        if (typeOf(bytes) == null) {
            throw new ApiException(ErrorCode.UNSUPPORTED_MEDIA_TYPE);
        }
        String path = storage.save(row.householdId(), photoId, bytes);
        // 送れたことを相手の端末へ知らせるため、通し番号を進める
        jdbc.sql("""
                UPDATE record_photos SET file_path = :path, size_bytes = :size, updated_at = now(),
                  server_seq = nextval('sync_seq')
                WHERE id = :id
                """).param("id", photoId).param("path", path).param("size", bytes.length).update();
    }

    byte[] download(UUID userId, UUID photoId) throws IOException {
        PhotoRow row = find(userId, photoId);
        if (row.filePath() == null) {
            throw new ApiException(ErrorCode.NOT_FOUND);
        }
        return storage.load(row.filePath());
    }

    /** ファイルの先頭の印で形式を見分ける。JPEG・PNG・WebP 以外は null（Content-Type は端末の申告なので信用しない）。 */
    public static MediaType typeOf(byte[] b) {
        if (b.length >= 3 && (b[0] & 0xFF) == 0xFF && (b[1] & 0xFF) == 0xD8 && (b[2] & 0xFF) == 0xFF) {
            return MediaType.IMAGE_JPEG;
        }
        if (b.length >= 8 && (b[0] & 0xFF) == 0x89 && b[1] == 'P' && b[2] == 'N' && b[3] == 'G') {
            return MediaType.IMAGE_PNG;
        }
        if (b.length >= 12 && b[0] == 'R' && b[1] == 'I' && b[2] == 'F' && b[3] == 'F'
                && b[8] == 'W' && b[9] == 'E' && b[10] == 'B' && b[11] == 'P') {
            return MediaType.parseMediaType("image/webp");
        }
        return null;
    }
}
