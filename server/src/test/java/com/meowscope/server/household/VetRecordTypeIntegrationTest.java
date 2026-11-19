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
import org.springframework.test.web.servlet.ResultActions;
import tools.jackson.databind.json.JsonMapper;

/** 標準の項目「病院」（Ver.1.3.0。F-MD-01、BR-37。DB 設計書 4章）。 */
@IntegrationTest
class VetRecordTypeIntegrationTest {

    @Autowired
    MockMvc mvc;

    @Autowired
    JdbcClient jdbc;

    @Autowired
    JsonMapper json;

    @Autowired
    DataSource dataSource;

    private static Map<String, Object> type(UUID id, String name, String icon, String kind, int sort) {
        return Map.of("id", id, "name", name, "icon", icon, "kind", kind, "sortOrder", sort);
    }

    private ResultActions create(Registered user, UUID id, List<Map<String, Object>> types) throws Exception {
        String body = json.writeValueAsString(Map.of("id", id, "name", "みけ家", "recordTypes", types));
        return mvc.perform(post("/api/v1/households").header("Authorization", user.bearer())
                .contentType(MediaType.APPLICATION_JSON).content(body));
    }

    private List<Map<String, Object>> vets(UUID household) {
        return jdbc.sql("SELECT name, icon, sort_order FROM record_types WHERE household_id = :h AND kind = 'vet'")
                .param("h", household).query().listOfRows();
    }

    @Test
    @DisplayName("IT-VT-01 古いアプリ（病院なしの8項目）でおうちを作ると、サーバーが病院を1つ、最後の並び順で足す")
    void 古いアプリの作成() throws Exception {
        Registered haru = TestUsers.register(mvc);
        UUID household = UUID.randomUUID();
        create(haru, household, List.of(
                type(UUID.randomUUID(), "ご飯", "food", "food", 0),
                type(UUID.randomUUID(), "ブラシ", "brushing", "brushing", 7)))
                .andExpect(status().isCreated());

        List<Map<String, Object>> vets = vets(household);
        assertThat(vets).hasSize(1);
        assertThat(vets.getFirst()).containsEntry("name", "病院").containsEntry("icon", "custom_vet")
                .containsEntry("sort_order", 8);

        // 送り直しでは足さない
        create(haru, household, List.of()).andExpect(status().isOk());
        assertThat(vets(household)).hasSize(1);
    }

    @Test
    @DisplayName("IT-VT-02 新しいアプリ（病院を含む9項目）でおうちを作ると、送った病院だけで、サーバーは足さない")
    void 新しいアプリの作成() throws Exception {
        Registered haru = TestUsers.register(mvc);
        UUID household = UUID.randomUUID();
        UUID vet = UUID.randomUUID();
        create(haru, household, List.of(
                type(UUID.randomUUID(), "ご飯", "food", "food", 0),
                type(vet, "病院", "custom_vet", "vet", 8)))
                .andExpect(status().isCreated());

        assertThat(jdbc.sql("SELECT id FROM record_types WHERE household_id = :h AND kind = 'vet'")
                .param("h", household).query(UUID.class).list()).containsExactly(vet);
    }

    @Test
    @DisplayName("IT-VT-03 異常系：病院を2つ送っておうちを作ると 409 で、おうちも作らない。知らない種類は 400")
    void 病院が2つ() throws Exception {
        Registered haru = TestUsers.register(mvc);
        UUID household = UUID.randomUUID();
        create(haru, household, List.of(
                type(UUID.randomUUID(), "病院", "custom_vet", "vet", 0),
                type(UUID.randomUUID(), "病院2", "custom_vet", "vet", 1)))
                .andExpect(status().isConflict());
        assertThat(jdbc.sql("SELECT count(*) FROM households WHERE id = :h").param("h", household)
                .query(Long.class).single()).isZero();

        create(haru, UUID.randomUUID(), List.of(type(UUID.randomUUID(), "x", "x", "hospital", 0)))
                .andExpect(status().isBadRequest());
    }

    @Test
    @DisplayName("IT-VT-04 同期：病院の行を受け取れ、2つ目の病院は constraint で受け付けない。病院の記録の detail を保存して返す")
    void 同期() throws Exception {
        Registered haru = TestUsers.register(mvc);
        UUID household = UUID.randomUUID();
        UUID vet = UUID.randomUUID();
        create(haru, household, List.of(type(vet, "病院", "custom_vet", "vet", 8))).andExpect(status().isCreated());

        UUID cat = UUID.randomUUID();
        UUID record = UUID.randomUUID();
        UUID second = UUID.randomUUID();
        Map<String, Object> recordData = new LinkedHashMap<>();
        recordData.put("catId", cat.toString());
        recordData.put("recordTypeId", vet.toString());
        recordData.put("recordedAt", "2026-11-19T01:00:00Z");
        recordData.put("authorName", "はる");
        recordData.put("detail", Map.of("hospital", "みどり動物病院", "nextDate", "2026-12-01"));
        String body = json.writeValueAsString(Map.of("lastSeq", 0, "changes", List.of(
                change("cats", cat, Map.of("householdId", household.toString(), "name", "ミケ", "status", "active")),
                change("record_types", second, Map.of("householdId", household.toString(), "name", "病院2",
                        "icon", "custom_vet", "kind", "vet", "sortOrder", 9, "hidden", false)),
                change("records", record, recordData))));
        mvc.perform(post("/api/v1/sync").header("Authorization", haru.bearer())
                        .contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.results[0].status").value("applied"))
                .andExpect(jsonPath("$.results[1].status").value("rejected"))
                .andExpect(jsonPath("$.results[1].reason").value("constraint"))
                .andExpect(jsonPath("$.results[2].status").value("applied"))
                .andExpect(jsonPath("$.changes[?(@.table == 'record_types')].data.kind").value("vet"))
                .andExpect(jsonPath("$.changes[?(@.table == 'records')].data.detail.hospital")
                        .value("みどり動物病院"));
        assertThat(vets(household)).hasSize(1);
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

    @Test
    @DisplayName("IT-VT-05 V9：今あるおうちに病院を1つずつ最後の並び順で足し、通し番号を振る。項目のないおうちは 0 番。2つ目は索引で入らない")
    void V9のデータ移行() throws Exception {
        // 本物の DB の中に別の場所（スキーマ）を作り、V8 まで進めてから今あるおうちを入れ、V9 を流す
        String schema = "v9_" + UUID.randomUUID().toString().replace("-", "");
        Flyway.configure().dataSource(dataSource).schemas(schema).target("8").load().migrate();
        JdbcClient db = JdbcClient.create(dataSource);
        UUID withTypes = UUID.randomUUID();
        UUID empty = UUID.randomUUID();
        long before;
        // 準備の行は、そのスキーマの通し番号を使うよう、1つの接続で search_path を合わせて入れる
        // （既定のままだと、通し番号が元のスキーマの番号になり、V9 で振る番号と比べられない）
        try (Connection c = dataSource.getConnection(); Statement st = c.createStatement()) {
            st.execute("SET search_path TO " + schema);
            st.execute("INSERT INTO households (id, name) VALUES ('" + withTypes + "', 'みけ家'), ('"
                    + empty + "', 'たま家')");
            st.execute("INSERT INTO record_types (id, household_id, name, icon, kind, sort_order) VALUES "
                    + "(gen_random_uuid(), '" + withTypes + "', 'ご飯', 'food', 'food', 0), "
                    + "(gen_random_uuid(), '" + withTypes + "', 'おやつ', 'custom_treat', 'custom', 9)");
            try (ResultSet rs = st.executeQuery("SELECT max(server_seq) FROM record_types")) {
                rs.next();
                before = rs.getLong(1);
            }
            st.execute("SET search_path TO public");
        }

        Flyway.configure().dataSource(dataSource).schemas(schema).load().migrate();

        String vets = "SELECT sort_order, server_seq FROM " + schema + ".record_types "
                + "WHERE household_id = :h AND kind = 'vet' AND name = '病院' AND icon = 'custom_vet'";
        List<Map<String, Object>> a = db.sql(vets).param("h", withTypes).query().listOfRows();
        assertThat(a).hasSize(1);
        assertThat(a.getFirst().get("sort_order")).isEqualTo(10);
        assertThat((Long) a.getFirst().get("server_seq")).isGreaterThan(before);
        List<Map<String, Object>> b = db.sql(vets).param("h", empty).query().listOfRows();
        assertThat(b).hasSize(1);
        assertThat(b.getFirst().get("sort_order")).isEqualTo(0);

        org.assertj.core.api.Assertions.assertThatThrownBy(() -> db.sql("INSERT INTO " + schema
                        + ".record_types (id, household_id, name, kind) VALUES (gen_random_uuid(), :h, '病院', 'vet')")
                .param("h", withTypes).update()).isInstanceOf(org.springframework.dao.DuplicateKeyException.class);

        db.sql("DROP SCHEMA " + schema + " CASCADE").update();
    }

    @Test
    @DisplayName("IT-VT-06 病院の detail の検証：名前は1〜50文字（境界値）、日付は YYYY-MM-DD の正しい日付、ほかのキーは不可。病院以外の項目の detail には効かない")
    void detailの検証() throws Exception {
        Registered haru = TestUsers.register(mvc);
        UUID household = UUID.randomUUID();
        UUID vet = UUID.randomUUID();
        UUID food = UUID.randomUUID();
        create(haru, household, List.of(type(food, "ご飯", "food", "food", 0), type(vet, "病院", "custom_vet", "vet", 8)))
                .andExpect(status().isCreated());
        UUID cat = UUID.randomUUID();
        List<Object> details = List.of(
                Map.of("hospital", "あ".repeat(50), "nextDate", "2026-12-01"),
                Map.of("hospital", "あ".repeat(51)),
                Map.of("hospital", "  "),
                Map.of("nextDate", "2026-02-30"),
                Map.of("nextDate", "2026/12/01"),
                Map.of("note", "x"),
                Map.of("hospital", 1));
        List<Map<String, Object>> changes = new java.util.ArrayList<>();
        changes.add(change("cats", cat, Map.of("householdId", household.toString(), "name", "ミケ", "status", "active")));
        for (Object d : details) {
            Map<String, Object> data = new LinkedHashMap<>();
            data.put("catId", cat.toString());
            data.put("recordTypeId", vet.toString());
            data.put("recordedAt", "2026-11-19T01:00:00Z");
            data.put("authorName", "はる");
            data.put("detail", d);
            changes.add(change("records", UUID.randomUUID(), data));
        }
        // 病院以外の項目（ご飯）の detail は、ここでは見ない
        Map<String, Object> other = new LinkedHashMap<>();
        other.put("catId", cat.toString());
        other.put("recordTypeId", food.toString());
        other.put("recordedAt", "2026-11-19T01:00:00Z");
        other.put("authorName", "はる");
        other.put("detail", Map.of("note", "x"));
        changes.add(change("records", UUID.randomUUID(), other));

        String body = json.writeValueAsString(Map.of("lastSeq", 0, "changes", changes));
        mvc.perform(post("/api/v1/sync").header("Authorization", haru.bearer())
                        .contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.results[0].status").value("applied"))
                .andExpect(jsonPath("$.results[1].status").value("applied"))
                .andExpect(jsonPath("$.results[2].field").value("detail"))
                .andExpect(jsonPath("$.results[3].field").value("detail"))
                .andExpect(jsonPath("$.results[4].field").value("detail"))
                .andExpect(jsonPath("$.results[5].field").value("detail"))
                .andExpect(jsonPath("$.results[6].field").value("detail"))
                .andExpect(jsonPath("$.results[7].field").value("detail"))
                .andExpect(jsonPath("$.results[2].reason").value("invalid"))
                .andExpect(jsonPath("$.results[8].status").value("applied"));
    }
}
