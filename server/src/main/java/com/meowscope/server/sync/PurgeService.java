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
 *   <li>消したら、新しい通し番号を {@code sync_purges} に残す。それより前の位置から同期してきた端末には、
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
        // 画像のファイルは、行を消す前に場所を控える。削除の印のない子の行も、親と一緒に（CASCADE で）消えるので含める
        List<String> files = new java.util.ArrayList<>(jdbc.sql("""
                SELECT p.file_path FROM record_photos p JOIN records r ON r.id = p.record_id
                JOIN record_types t ON t.id = r.record_type_id JOIN cats c ON c.id = r.cat_id
                JOIN households h ON h.id = c.household_id
                WHERE p.file_path IS NOT NULL AND (p.deleted_at < :before OR r.deleted_at < :before
                  OR t.deleted_at < :before OR c.deleted_at < :before OR h.deleted_at < :before)
                """).param("before", before).query(String.class).list());
        files.addAll(jdbc.sql("""
                SELECT c.icon_path FROM cats c JOIN households h ON h.id = c.household_id
                WHERE c.icon_path IS NOT NULL AND (c.deleted_at < :before OR h.deleted_at < :before)
                """).param("before", before).query(String.class).list());
        int total = 0;
        for (String table : TABLES) {
            total += jdbc.sql("DELETE FROM " + table + " WHERE deleted_at < :before").param("before", before)
                    .update();
        }
        if (total > 0) {
            // 消えた行（一緒に消えた子の行も）の削除は差分では届かない。新しい番号で purged_seq を進め、
            // それより前の位置の端末に全件を取り直させる（V7 の sync_next_seq）
            jdbc.sql("UPDATE sync_purges SET purged_seq = sync_next_seq(), purged_at = :now WHERE id = 1")
                    .param("now", Timestamp.from(now)).update();
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
