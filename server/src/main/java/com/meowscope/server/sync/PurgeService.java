package com.meowscope.server.sync;

import com.meowscope.server.photo.PhotoStorage;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 削除の印（deleted_at）から90日を過ぎた行を完全に消す（DB 設計書 7章、BR-29）。毎日1回動く。
 *
 * <ul>
 *   <li>参照する側から消す：写真 → 記録 → ウィジェットのボタン → 記録項目 → 猫 → おうちのメンバー → おうち
 *   <li>写真は、サーバーの画像のファイルも消す
 *   <li>消した行の通し番号の最大を {@code sync_purges} に残す。それより前の位置から同期してきた端末には、
 *       全件の取り直しを指示する（消えた行の削除を受け取れないため。{@link SyncReader#fullResyncRequired}）
 *   <li>期限が切れて使えなくなったログインのトークン・招待・確認コードも片付ける
 * </ul>
 */
@Service
public class PurgeService {

    private static final Logger log = LoggerFactory.getLogger(PurgeService.class);

    /** 削除の印を付けてから、完全に消すまでの期間。 */
    static final Duration RETENTION = Duration.ofDays(90);

    /** 消す順番（参照する側から）。 */
    static final List<String> TABLES = List.of("record_photos", "records", "widget_buttons", "record_types", "cats",
            "household_members", "households");

    private final JdbcClient jdbc;
    private final PhotoStorage storage;
    private final Clock clock;

    PurgeService(JdbcClient jdbc, PhotoStorage storage, Clock clock) {
        this.jdbc = jdbc;
        this.storage = storage;
        this.clock = clock;
    }

    /** 毎日 3 時（日本時間）に動かす。 */
    @Scheduled(cron = "0 0 3 * * *", zone = "Asia/Tokyo")
    public void scheduled() {
        purge();
    }

    /** 消した行の数を返す。 */
    @Transactional
    public int purge() {
        Instant now = clock.instant();
        Timestamp before = Timestamp.from(now.minus(RETENTION));
        // 写真のファイルは、行を消す前に場所を控える
        List<String> files = jdbc.sql("""
                SELECT file_path FROM record_photos
                WHERE deleted_at < :before AND file_path IS NOT NULL
                """).param("before", before).query(String.class).list();
        long maxSeq = 0;
        int total = 0;
        for (String table : TABLES) {
            // 消す行がない表では max が空になるので、0 として読む
            long seq = jdbc.sql("SELECT COALESCE(max(server_seq), 0) FROM " + table + " WHERE deleted_at < :before")
                    .param("before", before).query(Long.class).single();
            int count = jdbc.sql("DELETE FROM " + table + " WHERE deleted_at < :before").param("before", before)
                    .update();
            maxSeq = Math.max(maxSeq, seq);
            total += count;
        }
        if (total > 0) {
            jdbc.sql("""
                    UPDATE sync_purges SET purged_seq = GREATEST(purged_seq, :seq), purged_at = :now WHERE id = 1
                    """).param("seq", maxSeq).param("now", Timestamp.from(now)).update();
        }
        int housekeeping = jdbc.sql("""
                DELETE FROM refresh_tokens WHERE expires_at < :before OR revoked_at < :before
                """).param("before", before).update()
                + jdbc.sql("DELETE FROM invitations WHERE expires_at < :before").param("before", before).update()
                + jdbc.sql("DELETE FROM password_resets WHERE expires_at < :now").param("now", Timestamp.from(now))
                        .update();
        files.forEach(storage::delete);
        log.atInfo().addKeyValue("evt.name", "purge").addKeyValue("evt.outcome", "success")
                .addKeyValue("purge.rows", total).addKeyValue("purge.files", files.size())
                .addKeyValue("purge.housekeeping", housekeeping).log("削除から90日を過ぎたデータを消した");
        return total;
    }
}
