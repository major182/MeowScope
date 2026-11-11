package com.meowscope.server.release;

import com.meowscope.server.common.error.ApiException;
import com.meowscope.server.common.error.ErrorCode;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Arrays;
import java.util.regex.Pattern;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import tools.jackson.core.JacksonException;
import tools.jackson.databind.json.JsonMapper;

/**
 * アプリの新しい版を、決まったフォルダーから読む（API 設計書 10章、デプロイ設計書 6.4）。
 *
 * <p>フォルダーは {@code <RELEASES_DIR>/<platform>/} で、版の情報 {@code release.json} とファイルを1組だけ置く。
 * サーバーは読むだけで、置くのは開発者のスクリプト。DB は使わない。
 */
@Service
public class ReleaseService {

    private static final Logger log = LoggerFactory.getLogger(ReleaseService.class);

    private static final Pattern SHA256 = Pattern.compile("[0-9a-f]{64}");

    /** 対応する端末と、置くファイルの名前。名前を決めておき、パスの書き換え（../ など）を受け付けない。 */
    public enum Platform {
        ANDROID("android", "meowscope.apk"),
        WINDOWS("windows", "meowscope-setup.exe");

        private final String key;
        private final String fileName;

        Platform(String key, String fileName) {
            this.key = key;
            this.fileName = fileName;
        }

        /** パスの文字から選ぶ。知らない値は 404（API 設計書 10章：platform が違うときは 404）。 */
        static Platform of(String value) {
            return Arrays.stream(values()).filter(p -> p.key.equals(value)).findFirst()
                    .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND));
        }
    }

    /** 版の情報。アプリは buildNumber が自分より大きいときだけ知らせる（BR-34）。 */
    public record Release(String version, int buildNumber, String sha256, long sizeBytes) {
    }

    private final Path root;
    private final JsonMapper json;

    public ReleaseService(@Value("${meowscope.releases.dir}") String dir, JsonMapper json) {
        this.root = Path.of(dir).toAbsolutePath().normalize();
        this.json = json;
    }

    /** いちばん新しい版の情報。置いていなければ 404。 */
    public Release latest(String platform) {
        Platform p = Platform.of(platform);
        Path info = root.resolve(p.key).resolve("release.json");
        if (!Files.isRegularFile(info) || !Files.isRegularFile(fileOf(p))) {
            throw new ApiException(ErrorCode.NOT_FOUND);
        }
        Release release;
        try {
            release = json.readValue(info.toFile(), Release.class);
        } catch (JacksonException e) {
            // 置き方の誤り。アプリには「確かめられない」と同じに見えるよう 500 にし、開発者が気づけるようログに残す
            log.atError().setCause(e).addKeyValue("evt.name", "release_read")
                    .log("版の情報を読めない（端末：{}）", p.key);
            throw new ApiException(ErrorCode.INTERNAL_ERROR);
        }
        if (!valid(release)) {
            log.atError().addKeyValue("evt.name", "release_read").log("版の情報の値が正しくない（端末：{}）", p.key);
            throw new ApiException(ErrorCode.INTERNAL_ERROR);
        }
        return release;
    }

    /** いちばん新しい版のファイルの場所。版の情報と同じく、置いていなければ 404。 */
    public Path file(String platform) {
        Platform p = Platform.of(platform);
        Path file = fileOf(p);
        if (!Files.isRegularFile(file)) {
            throw new ApiException(ErrorCode.NOT_FOUND);
        }
        return file;
    }

    private Path fileOf(Platform p) {
        return root.resolve(p.key).resolve(p.fileName);
    }

    /** 端末が比べたり照合したりできない値は、置き方の誤りとして扱う。 */
    static boolean valid(Release r) {
        return r.version() != null && !r.version().isBlank() && r.buildNumber() > 0
                && r.sha256() != null && SHA256.matcher(r.sha256()).matches() && r.sizeBytes() > 0;
    }
}
