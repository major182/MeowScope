package com.meowscope.server.household;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.meowscope.server.IntegrationTest;
import com.meowscope.server.TestUsers;
import com.meowscope.server.TestUsers.Registered;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.Statement;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import javax.sql.DataSource;
import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.test.web.servlet.MockMvc;
import tools.jackson.databind.json.JsonMapper;

/** 独自の項目「通院」を「病院」へまとめる（Ver.1.3.0。BR-38。DB 設計書 4章）。 */
@IntegrationTest
class MergeCustomVetIntegrationTest {

    @Autowired
    MockMvc mvc;

    @Autowired
    JdbcClient jdbc;

    @Autowired
    JsonMapper json;

    @Autowired
    DataSource dataSource;

    /** そのスキーマで1つの値を読む。 */
    private static Object one(Statement st, String sql) throws Exception {
        try (ResultSet rs = st.executeQuery(sql)) {
            return rs.next() ? rs.getObject(1) : null;
        }
    }

    @Test
    @DisplayName("IT-MV-01 V10：通院の独自の項目の記録（消した記録も）を同じおうちの病院へ付け替え、その項目とボタンを消す。"
            + "ほかの独自の項目・ほかのおうち・通院のないおうちは変えない。通し番号が進む")
    void V10のデータ移行() throws Exception {
        // 本物の DB の中に別の場所（スキーマ）を作り、V8 まで進めてから今あるデータを入れ、V9・V10 を流す
        String schema = "v10_" + UUID.randomUUID().toString().replace("-", "");
        Flyway.configure().dataSource(dataSource).schemas(schema).target("8").load().migrate();
        String h1 = UUID.randomUUID().toString();
        String h2 = UUID.randomUUID().toString();
        String h3 = UUID.randomUUID().toString();
        String visit1 = UUID.randomUUID().toString();
        String visit2 = UUID.randomUUID().toString();
        String nail = UUID.randomUUID().toString();
        String r1 = UUID.randomUUID().toString();
        String r2 = UUID.randomUUID().toString();
        String r3 = UUID.randomUUID().toString();
        String rNail = UUID.randomUUID().toString();
        String button = UUID.randomUUID().toString();
        String cat1 = UUID.randomUUID().toString();
        String cat2 = UUID.randomUUID().toString();
        String user = UUID.randomUUID().toString();
        long before;
        try (Connection c = dataSource.getConnection(); Statement st = c.createStatement()) {
            // 準備の行は、そのスキーマの通し番号を使うよう search_path を合わせる
            st.execute("SET search_path TO " + schema);
            st.execute("INSERT INTO users (id, email, password_hash, display_name) VALUES ('" + user
                    + "', 'a@example.com', 'x', 'はる')");
            st.execute("INSERT INTO households (id, name) VALUES ('" + h1 + "', 'みけ家'), ('" + h2 + "', 'たま家'), ('"
                    + h3 + "', 'そら家')");
            st.execute("INSERT INTO cats (id, household_id, name) VALUES ('" + cat1 + "', '" + h1 + "', 'ミケ'), ('"
                    + cat2 + "', '" + h2 + "', 'タマ')");
            // h1：通院（名前は自由）と爪切り。h2：通院。h3：独自の項目なし
            st.execute("INSERT INTO record_types (id, household_id, name, icon, kind, sort_order) VALUES "
                    + "('" + visit1 + "', '" + h1 + "', 'どうぶつ病院', 'custom_vet', 'custom', 8), "
                    + "('" + nail + "', '" + h1 + "', '爪切り', 'custom_nail', 'custom', 9), "
                    + "('" + visit2 + "', '" + h2 + "', '通院', 'custom_vet', 'custom', 8)");
            st.execute("INSERT INTO records (id, cat_id, record_type_id, recorded_at, author_name, memo, deleted_at)"
                    + " VALUES ('" + r1 + "', '" + cat1 + "', '" + visit1 + "', now(), 'はる', 'ワクチン', null), "
                    + "('" + r2 + "', '" + cat1 + "', '" + visit1 + "', now(), 'はる', null, now()), "
                    + "('" + rNail + "', '" + cat1 + "', '" + nail + "', now(), 'はる', null, null), "
                    + "('" + r3 + "', '" + cat2 + "', '" + visit2 + "', now(), 'はる', null, null)");
            st.execute("INSERT INTO widget_buttons (id, user_id, record_type_id, sort_order) VALUES ('" + button
                    + "', '" + user + "', '" + visit1 + "', 0)");
            // 準備で振った番号の最後（ボタンを最後に入れた）。まとめた後の行は、これより大きい番号になる
            before = ((Number) one(st, "SELECT max(server_seq) FROM widget_buttons")).longValue();

            Flyway.configure().dataSource(dataSource).schemas(schema).load().migrate();

            String vet1 = one(st, "SELECT id FROM record_types WHERE household_id = '" + h1 + "' AND kind = 'vet'")
                    .toString();
            String vet2 = one(st, "SELECT id FROM record_types WHERE household_id = '" + h2 + "' AND kind = 'vet'")
                    .toString();
            // 記録は同じおうちの病院へ（消した記録も）。メモなどはそのまま
            assertThat(one(st, "SELECT record_type_id FROM records WHERE id = '" + r1 + "'").toString())
                    .isEqualTo(vet1);
            assertThat(one(st, "SELECT memo FROM records WHERE id = '" + r1 + "'")).isEqualTo("ワクチン");
            assertThat(one(st, "SELECT record_type_id FROM records WHERE id = '" + r2 + "'").toString())
                    .isEqualTo(vet1);
            assertThat(one(st, "SELECT record_type_id FROM records WHERE id = '" + r3 + "'").toString())
                    .isEqualTo(vet2);
            assertThat(((Number) one(st, "SELECT server_seq FROM records WHERE id = '" + r1 + "'")).longValue())
                    .isGreaterThan(before);
            // ほかの独自の項目とその記録は変えない
            assertThat(one(st, "SELECT record_type_id FROM records WHERE id = '" + rNail + "'").toString())
                    .isEqualTo(nail);
            assertThat(one(st, "SELECT deleted_at FROM record_types WHERE id = '" + nail + "'")).isNull();
            // 通院の項目とボタンは消える
            assertThat(one(st, "SELECT deleted_at FROM record_types WHERE id = '" + visit1 + "'")).isNotNull();
            assertThat(one(st, "SELECT deleted_at FROM record_types WHERE id = '" + visit2 + "'")).isNotNull();
            assertThat(one(st, "SELECT deleted_at FROM widget_buttons WHERE id = '" + button + "'")).isNotNull();
            // 消した項目とボタンも番号が進み、端末へ届く
            assertThat(((Number) one(st, "SELECT server_seq FROM record_types WHERE id = '" + visit1 + "'"))
                    .longValue()).isGreaterThan(before);
            assertThat(((Number) one(st, "SELECT server_seq FROM widget_buttons WHERE id = '" + button + "'"))
                    .longValue()).isGreaterThan(before);
            // 通院のないおうちにも病院は1つだけ（V9）
            assertThat(((Number) one(st, "SELECT count(*) FROM record_types WHERE household_id = '" + h3
                    + "'")).longValue()).isEqualTo(1);
            st.execute("SET search_path TO public");
        }
        jdbc.sql("DROP SCHEMA " + schema + " CASCADE").update();
    }

    private static Map<String, Object> change(String table, UUID id, Map<String, Object> data) {
        Map<String, Object> c = new LinkedHashMap<>();
        c.put("table", table);
        c.put("id", id);
        c.put("updatedAt", "2026-11-19T00:00:00Z");
        c.put("deletedAt", null);
        c.put("data", data);
        return c;
    }

    private Map<String, Object> recordData(UUID cat, UUID type) {
        Map<String, Object> d = new LinkedHashMap<>();
        d.put("catId", cat.toString());
        d.put("recordTypeId", type.toString());
        d.put("recordedAt", "2026-11-19T01:00:00Z");
        d.put("authorName", "はる");
        return d;
    }

    @Test
    @DisplayName("IT-MV-02 同期：まとめた項目を指す記録が古い端末から届いたら、病院へ付け替えて保存し、付け替えた内容を返す。"
            + "まとめていない通院の項目（消していない）と、ほかの独自の項目はそのまま")
    void 古い端末からの記録() throws Exception {
        Registered haru = TestUsers.register(mvc);
        UUID household = UUID.randomUUID();
        UUID vet = UUID.randomUUID();
        String body = json.writeValueAsString(Map.of("id", household, "name", "みけ家", "recordTypes", List.of(
                Map.of("id", vet, "name", "病院", "icon", "custom_vet", "kind", "vet", "sortOrder", 8))));
        mvc.perform(post("/api/v1/households").header("Authorization", haru.bearer())
                .contentType(MediaType.APPLICATION_JSON).content(body)).andExpect(status().isCreated());
        UUID cat = UUID.randomUUID();
        UUID merged = UUID.randomUUID();
        UUID kept = UUID.randomUUID();
        Map<String, Object> custom = new LinkedHashMap<>(Map.of("householdId", household.toString(),
                "name", "通院", "icon", "custom_vet", "kind", "custom", "sortOrder", 9, "hidden", false));
        Map<String, Object> custom2 = new LinkedHashMap<>(custom);
        custom2.put("name", "通院2");
        custom2.put("sortOrder", 10);
        sync(haru, List.of(
                change("cats", cat, Map.of("householdId", household.toString(), "name", "ミケ", "status", "active")),
                change("record_types", merged, custom),
                change("record_types", kept, custom2)));
        // V10 でまとめた後の状態にする（項目に削除の印）
        jdbc.sql("UPDATE record_types SET deleted_at = now() WHERE id = :id").param("id", merged).update();

        UUID toMerged = UUID.randomUUID();
        UUID toKept = UUID.randomUUID();
        String reply = sync(haru, List.of(
                change("records", toMerged, recordData(cat, merged)),
                change("records", toKept, recordData(cat, kept))));

        assertThat(jdbc.sql("SELECT record_type_id FROM records WHERE id = :id").param("id", toMerged)
                .query(UUID.class).single()).isEqualTo(vet);
        assertThat(jdbc.sql("SELECT record_type_id FROM records WHERE id = :id").param("id", toKept)
                .query(UUID.class).single()).isEqualTo(kept);
        assertThat(reply).contains("\"recordTypeId\":\"" + vet + "\"");
    }

    private String sync(Registered user, List<Map<String, Object>> changes) throws Exception {
        String body = json.writeValueAsString(Map.of("lastSeq", 0, "changes", changes));
        return mvc.perform(post("/api/v1/sync").header("Authorization", user.bearer())
                        .contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.results[*].status").value(org.hamcrest.Matchers.everyItem(
                        org.hamcrest.Matchers.is("applied"))))
                .andReturn().getResponse().getContentAsString();
    }
}
