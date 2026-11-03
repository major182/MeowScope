package com.meowscope.server.household;

import com.meowscope.server.common.error.ApiException;
import com.meowscope.server.common.error.ErrorCode;
import com.meowscope.server.common.logging.Severity;
import com.meowscope.server.photo.PhotoStorage;
import java.util.List;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * おうちを抜ける（F-SH-03、BR-16、BR-19、DB 設計書 7章）。退会（DELETE /me）でも同じ処理を使う。
 *
 * <ul>
 *   <li>残す：メンバーの行に削除の印を付ける
 *   <li>消す：上に加えて、本人の投稿（記録とその写真）に削除の印を付ける
 *   <li>最後の1人：おうちとその中のデータをすべて物理削除する（写真のファイルも消す）
 * </ul>
 *
 * <p>削除の印を付けた行は通し番号を進め、相手の端末へ同期で届ける。
 */
@Service
public class LeaveService {

    private static final Logger log = LoggerFactory.getLogger(LeaveService.class);

    private final JdbcClient jdbc;
    private final HouseholdAccess access;
    private final PhotoStorage storage;

    LeaveService(JdbcClient jdbc, HouseholdAccess access, PhotoStorage storage) {
        this.jdbc = jdbc;
        this.access = access;
        this.storage = storage;
    }

    /**
     * 抜ける。
     *
     * @return 最後の1人で、おうちごと消したら true
     * @throws ApiException 自分のおうちでなければ 404
     */
    @Transactional
    public boolean leave(UUID userId, UUID householdId, boolean keepRecords) {
        if (!access.isMember(userId, householdId)) {
            throw new ApiException(ErrorCode.NOT_FOUND);
        }
        long others = jdbc.sql("""
                SELECT count(*) FROM household_members
                WHERE household_id = :h AND deleted_at IS NULL AND user_id <> :u
                """).param("h", householdId).param("u", userId).query(Long.class).single();
        boolean last = others == 0;
        if (last) {
            deleteHousehold(householdId);
        } else {
            if (!keepRecords) {
                deletePosts(userId, householdId);
            }
            jdbc.sql("""
                    UPDATE household_members SET deleted_at = now(), updated_at = now(),
                      server_seq = nextval('sync_seq')
                    WHERE household_id = :h AND user_id = :u AND deleted_at IS NULL
                    """).param("h", householdId).param("u", userId).update();
        }
        log.atInfo().addMarker(Severity.NOTICE).addKeyValue("evt.name", "household_leave")
                .addKeyValue("evt.outcome", "success").addKeyValue("usr.id", userId.toString())
                .addKeyValue("household.id", householdId.toString())
                .addKeyValue("evt.reason", last ? "last_member" : keepRecords ? "keep" : "delete")
                .log("おうちを抜けた");
        return last;
    }

    /** 自分が今属しているおうち。 */
    public List<UUID> householdsOf(UUID userId) {
        return jdbc.sql("SELECT household_id FROM household_members WHERE user_id = :u AND deleted_at IS NULL")
                .param("u", userId).query(UUID.class).list();
    }

    private void deletePosts(UUID userId, UUID householdId) {
        String mine = """
                SELECT r.id FROM records r JOIN cats c ON c.id = r.cat_id
                WHERE c.household_id = :h AND r.author_id = :u AND r.deleted_at IS NULL
                """;
        List<String> files = jdbc.sql("SELECT file_path FROM record_photos WHERE deleted_at IS NULL"
                + " AND file_path IS NOT NULL AND record_id IN (" + mine + ")")
                .param("h", householdId).param("u", userId).query(String.class).list();
        jdbc.sql("UPDATE record_photos SET deleted_at = now(), updated_at = now(), server_seq = nextval('sync_seq')"
                + " WHERE deleted_at IS NULL AND record_id IN (" + mine + ")")
                .param("h", householdId).param("u", userId).update();
        jdbc.sql("UPDATE records SET deleted_at = now(), updated_at = now(), server_seq = nextval('sync_seq')"
                + " WHERE id IN (" + mine + ")")
                .param("h", householdId).param("u", userId).update();
        files.forEach(storage::delete);
    }

    private void deleteHousehold(UUID householdId) {
        List<String> files = jdbc.sql("""
                SELECT p.file_path FROM record_photos p JOIN records r ON r.id = p.record_id
                JOIN cats c ON c.id = r.cat_id WHERE c.household_id = :h AND p.file_path IS NOT NULL
                """).param("h", householdId).query(String.class).list();
        // 表の外部キーは ON DELETE CASCADE なので、おうちを消せば中のデータもすべて消える
        jdbc.sql("DELETE FROM households WHERE id = :h").param("h", householdId).update();
        files.forEach(storage::delete);
    }
}
