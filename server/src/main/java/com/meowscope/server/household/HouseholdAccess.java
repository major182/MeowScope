package com.meowscope.server.household;

import java.util.Optional;
import java.util.UUID;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

/**
 * おうちの権限の確認（NF-SC-04：自分が属するおうちのデータにだけアクセスできる）。
 *
 * <p>同期とおうちの API は、行を読み書きする前に必ずここで確かめる。
 */
@Repository
public class HouseholdAccess {

    private final JdbcClient jdbc;

    public HouseholdAccess(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    /** いま有効なメンバーか（抜けた人は含めない）。 */
    public boolean isMember(UUID userId, UUID householdId) {
        return jdbc.sql("""
                SELECT count(*) FROM household_members m JOIN households h ON h.id = m.household_id
                WHERE m.user_id = :user AND m.household_id = :household
                  AND m.deleted_at IS NULL AND h.deleted_at IS NULL
                """).param("user", userId).param("household", householdId).query(Long.class).single() > 0;
    }

    public boolean householdExists(UUID householdId) {
        return jdbc.sql("SELECT count(*) FROM households WHERE id = :id").param("id", householdId)
                .query(Long.class).single() > 0;
    }

    public Optional<UUID> householdOfCat(UUID catId) {
        return jdbc.sql("SELECT household_id FROM cats WHERE id = :id").param("id", catId)
                .query(UUID.class).optional();
    }

    public Optional<UUID> householdOfRecordType(UUID typeId) {
        return jdbc.sql("SELECT household_id FROM record_types WHERE id = :id").param("id", typeId)
                .query(UUID.class).optional();
    }

    public Optional<UUID> householdOfRecord(UUID recordId) {
        return jdbc.sql("SELECT c.household_id FROM records r JOIN cats c ON c.id = r.cat_id WHERE r.id = :id")
                .param("id", recordId).query(UUID.class).optional();
    }
}
