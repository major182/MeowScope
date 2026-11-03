package com.meowscope.server.icon;

import com.meowscope.server.common.error.ApiException;
import com.meowscope.server.common.error.ErrorCode;
import com.meowscope.server.household.HouseholdAccess;
import com.meowscope.server.photo.PhotoService;
import com.meowscope.server.photo.PhotoStorage;
import java.io.IOException;
import java.io.InputStream;
import java.util.UUID;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;

/**
 * ユーザーと猫のアイコン（F-SH-07、API 設計書 3章・6章）。写真と同じく、画像だけを受け付け、権限を確かめる。
 *
 * <p>保存したら行の通し番号を進め、相手の端末へ「アイコンが変わった」ことを同期で届ける。
 */
@Service
public class IconService {

    /** 端末で 512px に縮めて送るので、1MB あれば足りる。 */
    static final int MAX_BYTES = 1024 * 1024;

    private final JdbcClient jdbc;
    private final HouseholdAccess access;
    private final PhotoStorage storage;

    IconService(JdbcClient jdbc, HouseholdAccess access, PhotoStorage storage) {
        this.jdbc = jdbc;
        this.access = access;
        this.storage = storage;
    }

    private static byte[] read(InputStream body) throws IOException {
        byte[] bytes = body.readNBytes(MAX_BYTES + 1);
        if (bytes.length > MAX_BYTES) {
            throw new ApiException(ErrorCode.PAYLOAD_TOO_LARGE);
        }
        if (PhotoService.typeOf(bytes) == null) {
            throw new ApiException(ErrorCode.UNSUPPORTED_MEDIA_TYPE);
        }
        return bytes;
    }

    void uploadUser(UUID userId, InputStream body) throws IOException {
        byte[] bytes = read(body);
        String path = storage.saveAt("icons/users/" + userId, bytes);
        jdbc.sql("""
                UPDATE users SET icon_path = :path, updated_at = now(), server_seq = nextval('sync_seq') WHERE id = :id
                """).param("id", userId).param("path", path).update();
    }

    /** 自分か、同じおうちのメンバーのアイコンだけを返す。 */
    byte[] downloadUser(UUID requester, UUID userId) throws IOException {
        boolean shares = requester.equals(userId) || jdbc.sql("""
                SELECT count(*) FROM household_members a JOIN household_members b ON a.household_id = b.household_id
                WHERE a.user_id = :me AND b.user_id = :other AND a.deleted_at IS NULL AND b.deleted_at IS NULL
                """).param("me", requester).param("other", userId).query(Long.class).single() > 0;
        String path = shares ? jdbc.sql("SELECT icon_path FROM users WHERE id = :id").param("id", userId)
                .query(String.class).optional().orElse(null) : null;
        if (path == null) {
            throw new ApiException(ErrorCode.NOT_FOUND);
        }
        return storage.load(path);
    }

    private UUID catHousehold(UUID requester, UUID catId) {
        UUID household = jdbc.sql("SELECT household_id FROM cats WHERE id = :id AND deleted_at IS NULL")
                .param("id", catId).query(UUID.class).optional()
                .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND));
        if (!access.isMember(requester, household)) {
            throw new ApiException(ErrorCode.NOT_FOUND);
        }
        return household;
    }

    void uploadCat(UUID requester, UUID catId, InputStream body) throws IOException {
        UUID household = catHousehold(requester, catId);
        byte[] bytes = read(body);
        String path = storage.saveAt(household + "/icons/" + catId, bytes);
        jdbc.sql("""
                UPDATE cats SET icon_path = :path, updated_at = now(), server_seq = nextval('sync_seq') WHERE id = :id
                """).param("id", catId).param("path", path).update();
    }

    byte[] downloadCat(UUID requester, UUID catId) throws IOException {
        catHousehold(requester, catId);
        String path = jdbc.sql("SELECT icon_path FROM cats WHERE id = :id").param("id", catId)
                .query(String.class).optional().orElse(null);
        if (path == null) {
            throw new ApiException(ErrorCode.NOT_FOUND);
        }
        return storage.load(path);
    }
}
