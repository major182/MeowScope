package com.meowscope.server.sync;

import com.meowscope.server.sync.SyncDtos.ChangeOut;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;
import tools.jackson.databind.json.JsonMapper;

/**
 * 端末へ送る変更を読む（API 設計書 5章）。自分が属するおうちの行と、自分の設定だけを返す（NF-SC-04）。
 *
 * <p>表ごとに「通し番号が {@code lastSeq} より後」の行を番号順に読み、すべての表をまとめて番号順に並べ直して、
 * 先頭から上限の件数までを返す。各表から上限＋1件ずつ読めば、まとめた後の先頭の上限件は必ず正しく揃う。
 * {@code data} は SQL の {@code json_build_object} で作り、送ってよい列だけを入れる（パスワードのハッシュとメールアドレスは入れない）。
 */
@Component
class SyncReader {

    /** 自分が今属しているおうち。 */
    private static final String MY_HOUSEHOLDS =
            "SELECT household_id FROM household_members WHERE user_id = :user AND deleted_at IS NULL";

    /** 表の名前、data を作る式、見てよい行の条件。 */
    private record Source(String table, String data, String visible) {
    }

    private static final List<Source> SOURCES = List.of(
            new Source("households", "json_build_object('name', name)", "id IN (" + MY_HOUSEHOLDS + ")"),
            // 自分の行は、抜けた後（deleted_at あり）も返す。別の端末で抜けたことを知らせるため
            new Source("household_members",
                    "json_build_object('householdId', household_id, 'userId', user_id,"
                            + " 'displayName', (SELECT display_name FROM users u WHERE u.id = t.user_id))",
                    "(household_id IN (" + MY_HOUSEHOLDS + ") OR user_id = :user)"),
            new Source("users", "json_build_object('displayName', display_name, 'hasIcon', icon_path IS NOT NULL)",
                    "id IN (SELECT user_id FROM household_members WHERE deleted_at IS NULL AND household_id IN ("
                            + MY_HOUSEHOLDS + "))"),
            new Source("cats",
                    "json_build_object('householdId', household_id, 'name', name, 'birthDate', birth_date,"
                            + " 'sex', sex, 'conditions', conditions, 'status', status, 'hasIcon', icon_path IS NOT NULL)",
                    "household_id IN (" + MY_HOUSEHOLDS + ")"),
            new Source("record_types",
                    "json_build_object('householdId', household_id, 'name', name, 'icon', icon, 'kind', kind,"
                            + " 'sortOrder', sort_order, 'hidden', hidden)",
                    "household_id IN (" + MY_HOUSEHOLDS + ")"),
            new Source("records",
                    "json_build_object('catId', cat_id, 'recordTypeId', record_type_id, 'recordedAt', recorded_at,"
                            + " 'authorId', author_id, 'authorName', author_name, 'valueNumber', value_number,"
                            + " 'level', level, 'detail', detail, 'memo', memo)",
                    "cat_id IN (SELECT id FROM cats WHERE household_id IN (" + MY_HOUSEHOLDS + "))"),
            // 画像の本体は送らず、送られたかどうか（uploaded）だけを伝える。端末は必要なときに GET /photos で取る
            new Source("record_photos",
                    "json_build_object('recordId', record_id, 'sortOrder', sort_order, 'sizeBytes', size_bytes,"
                            + " 'uploaded', file_path IS NOT NULL)",
                    "record_id IN (SELECT r.id FROM records r JOIN cats c ON c.id = r.cat_id WHERE c.household_id IN ("
                            + MY_HOUSEHOLDS + "))"),
            new Source("user_settings", "json_build_object('weekStart', week_start)", "user_id = :user"),
            // ウィジェットのボタンはアカウントのもの。自分の分だけを返す（BR-22）
            new Source("widget_buttons",
                    "json_build_object('recordTypeId', record_type_id, 'sortOrder', sort_order)", "user_id = :user"));

    private final JdbcClient jdbc;
    private final JsonMapper json;

    SyncReader(JdbcClient jdbc, JsonMapper json) {
        this.jdbc = jdbc;
        this.json = json;
    }

    /** 番号順に最大 {@code limit + 1} 件を返す。{@code limit} を超えていれば、まだ続きがある。 */
    List<ChangeOut> read(UUID userId, long lastSeq, int limit) {
        List<ChangeOut> all = new ArrayList<>();
        for (Source source : SOURCES) {
            String sql = "SELECT server_seq, id, updated_at, deleted_at, " + source.data() + "::text AS data FROM "
                    + source.table() + " t WHERE server_seq > :last AND " + source.visible()
                    + " ORDER BY server_seq LIMIT :limit";
            all.addAll(jdbc.sql(sql).param("user", userId).param("last", lastSeq).param("limit", limit + 1)
                    .query((rs, n) -> row(source.table(), rs)).list());
        }
        all.sort(Comparator.comparingLong(ChangeOut::seq));
        return all.size() > limit + 1 ? all.subList(0, limit + 1) : all;
    }

    /**
     * 全件の取り直しが要るか。
     *
     * <ul>
     *   <li>端末の番号がサーバーの最新より先（サーバーの DB を作り直した）
     *   <li>前回の同期の後に、自分が別のおうちに加わった（そのおうちの古い行は番号が小さく、差分では届かない）
     * </ul>
     */
    boolean fullResyncRequired(UUID userId, long lastSeq) {
        if (lastSeq == 0) {
            return false;
        }
        long latest = jdbc.sql("SELECT last_value FROM sync_seq").query(Long.class).single();
        if (lastSeq > latest) {
            return true;
        }
        return jdbc.sql("""
                SELECT count(*) FROM household_members
                WHERE user_id = :user AND deleted_at IS NULL AND server_seq > :last
                """).param("user", userId).param("last", lastSeq).query(Long.class).single() > 0;
    }

    @SuppressWarnings("unchecked")
    private ChangeOut row(String table, ResultSet rs) throws SQLException {
        Map<String, Object> data = json.readValue(rs.getString("data"), Map.class);
        return new ChangeOut(table, rs.getObject("id", UUID.class), rs.getLong("server_seq"),
                text(rs.getTimestamp("updated_at")), text(rs.getTimestamp("deleted_at")), data);
    }

    private static String text(Timestamp value) {
        return value == null ? null : value.toInstant().toString();
    }
}
