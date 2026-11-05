package com.meowscope.server.household;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.meowscope.server.IntegrationTest;
import com.meowscope.server.TestUsers;
import com.meowscope.server.TestUsers.Registered;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.system.CapturedOutput;
import org.springframework.boot.test.system.OutputCaptureExtension;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import tools.jackson.databind.json.JsonMapper;

@IntegrationTest
@ExtendWith(OutputCaptureExtension.class)
class LeaveIntegrationTest {

    @Autowired
    MockMvc mvc;

    @Autowired
    JdbcClient jdbc;

    @Autowired
    JsonMapper json;

    Registered haru;
    Registered natsu;
    UUID household;
    UUID type;
    UUID cat;

    @BeforeEach
    void setUp() throws Exception {
        haru = TestUsers.register(mvc, TestUsers.uniqueEmail(), "はる");
        natsu = TestUsers.register(mvc, TestUsers.uniqueEmail(), "なつ");
        household = UUID.randomUUID();
        type = UUID.randomUUID();
        cat = UUID.randomUUID();
        mvc.perform(post("/api/v1/households").header("Authorization", haru.bearer())
                .contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("id", household, "name", "みけ家", "recordTypes", List.of(
                        Map.of("id", type, "name", "ご飯", "kind", "food", "sortOrder", 0))))))
                .andExpect(status().isCreated());
        jdbc.sql("INSERT INTO household_members (id, household_id, user_id) VALUES (gen_random_uuid(), :h, :u)")
                .param("h", household).param("u", natsu.id()).update();
        sync(haru, List.of(change("cats", cat, Map.of("householdId", household.toString(), "name", "ミケ",
                "status", "active"))));
    }

    private static Map<String, Object> change(String table, UUID id, Map<String, Object> data) {
        Map<String, Object> c = new LinkedHashMap<>();
        c.put("table", table);
        c.put("id", id);
        c.put("updatedAt", "2026-11-03T00:00:00Z");
        c.put("deletedAt", null);
        c.put("data", data);
        return c;
    }

    private void sync(Registered user, List<Map<String, Object>> changes) throws Exception {
        mvc.perform(post("/api/v1/sync").header("Authorization", user.bearer())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("lastSeq", 0, "changes", changes))))
                .andExpect(status().isOk());
    }

    /** 記録を1件作る（投稿者は user）。 */
    private UUID record(Registered user) throws Exception {
        UUID id = UUID.randomUUID();
        sync(user, List.of(change("records", id, Map.of("catId", cat.toString(), "recordTypeId", type.toString(),
                "recordedAt", "2026-11-03T08:00:00Z", "authorName", user.id().equals(haru.id()) ? "はる" : "なつ"))));
        return id;
    }

    private ResultActions leave(Registered user, UUID householdId, Boolean keep) throws Exception {
        return mvc.perform(post("/api/v1/households/" + householdId + "/leave").header("Authorization", user.bearer())
                .contentType(MediaType.APPLICATION_JSON).content("{\"keepRecords\":" + keep + "}"));
    }

    private ResultActions deleteMe(Registered user, Boolean keep) throws Exception {
        return mvc.perform(delete("/api/v1/me").header("Authorization", user.bearer())
                .contentType(MediaType.APPLICATION_JSON).content("{\"keepRecords\":" + keep + "}"));
    }

    private boolean deleted(UUID recordId) {
        return jdbc.sql("SELECT deleted_at IS NOT NULL FROM records WHERE id = :id").param("id", recordId)
                .query(Boolean.class).single();
    }

    private boolean memberActive(Registered user) {
        return jdbc.sql("""
                SELECT count(*) FROM household_members WHERE household_id = :h AND user_id = :u AND deleted_at IS NULL
                """).param("h", household).param("u", user.id()).query(Long.class).single() > 0;
    }

    @Test
    @DisplayName("IT-MG-01 抜ける（残す）：メンバーの行だけに削除の印。記録はそのまま（BR-16）")
    void 抜ける_残す() throws Exception {
        UUID mine = record(natsu);
        leave(natsu, household, true).andExpect(status().isOk()).andExpect(jsonPath("$.householdDeleted").value(false));
        assertThat(memberActive(natsu)).isFalse();
        assertThat(deleted(mine)).isFalse();
    }

    @Test
    @DisplayName("IT-MG-02 抜ける（消す）：本人の投稿にだけ削除の印。相手の投稿は残る")
    void 抜ける_消す() throws Exception {
        UUID mine = record(natsu);
        UUID theirs = record(haru);
        leave(natsu, household, false).andExpect(status().isOk());
        assertThat(deleted(mine)).isTrue();
        assertThat(deleted(theirs)).isFalse();
    }

    @Test
    @DisplayName("IT-MG-03 最後の1人が抜けると、おうちとその中のデータをすべて消す（BR-19）")
    void 最後の1人() throws Exception {
        record(haru);
        leave(natsu, household, true);
        leave(haru, household, true).andExpect(jsonPath("$.householdDeleted").value(true));
        assertThat(jdbc.sql("SELECT count(*) FROM households WHERE id = :h").param("h", household)
                .query(Long.class).single()).isZero();
        assertThat(jdbc.sql("SELECT count(*) FROM cats WHERE id = :c").param("c", cat).query(Long.class).single())
                .isZero();
    }

    @Test
    @DisplayName("IT-MG-04 異常系：属していない・抜けた後・ないおうちは 404。選択がなければ 400")
    void 抜けるの異常系() throws Exception {
        Registered other = TestUsers.register(mvc);
        leave(other, household, true).andExpect(status().isNotFound());
        leave(haru, UUID.randomUUID(), true).andExpect(status().isNotFound());
        leave(natsu, household, null).andExpect(status().isBadRequest());
        leave(natsu, household, true).andExpect(status().isOk());
        leave(natsu, household, true).andExpect(status().isNotFound());
    }

    @Test
    @DisplayName("IT-MG-05 退会（残す）：ユーザーを消し、記録は投稿者名を残して投稿者の ID が空。相手にはメンバーの削除が届く（BR-17）")
    void 退会_残す() throws Exception {
        UUID mine = record(natsu);
        deleteMe(natsu, true).andExpect(status().isNoContent());
        assertThat(jdbc.sql("SELECT count(*) FROM users WHERE id = :u").param("u", natsu.id())
                .query(Long.class).single()).isZero();
        Map<String, Object> row = jdbc.sql("SELECT author_id, author_name, deleted_at FROM records WHERE id = :id")
                .param("id", mine).query().singleRow();
        assertThat(row.get("author_id")).isNull();
        assertThat(row.get("author_name")).isEqualTo("なつ");
        assertThat(row.get("deleted_at")).isNull();
        assertThat(jdbc.sql("""
                SELECT count(*) FROM household_members WHERE household_id = :h AND user_id IS NULL
                  AND deleted_at IS NOT NULL
                """).param("h", household).query(Long.class).single()).isEqualTo(1);
        // 残っていたトークンは使えない
        mvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get("/api/v1/me")
                .header("Authorization", natsu.bearer())).andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("IT-MG-06 退会（消す）：本人の投稿に削除の印。最後の1人のおうちは消える")
    void 退会_消す() throws Exception {
        UUID mine = record(natsu);
        UUID own = UUID.randomUUID();
        mvc.perform(post("/api/v1/households").header("Authorization", natsu.bearer())
                .contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("id", own, "name", "なつ家", "recordTypes", List.of()))));
        deleteMe(natsu, false).andExpect(status().isNoContent());
        assertThat(deleted(mine)).isTrue();
        assertThat(jdbc.sql("SELECT count(*) FROM households WHERE id = :h").param("h", own)
                .query(Long.class).single()).isZero();
        deleteMe(haru, null).andExpect(status().isBadRequest());
    }

    @Test
    @DisplayName("IT-MG-07 パスワードの変更：今のパスワードが違えば 403。変えると新しいパスワードで入れ、古い更新トークンは使えない")
    void パスワードの変更(CapturedOutput output) throws Exception {
        mvc.perform(put("/api/v1/me/password").header("Authorization", haru.bearer())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"currentPassword\":\"wrong\",\"newPassword\":\"NewPassw0rd\"}"))
                .andExpect(status().isForbidden());
        mvc.perform(put("/api/v1/me/password").header("Authorization", haru.bearer())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"currentPassword\":\"" + TestUsers.PASSWORD + "\",\"newPassword\":\"short\"}"))
                .andExpect(status().isBadRequest());
        mvc.perform(put("/api/v1/me/password").header("Authorization", haru.bearer())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"currentPassword\":\"" + TestUsers.PASSWORD + "\",\"newPassword\":\"NewPassw0rd\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").isNotEmpty())
                .andExpect(jsonPath("$.refreshToken").isNotEmpty());
        mvc.perform(post("/api/v1/auth/refresh").contentType(MediaType.APPLICATION_JSON)
                .content("{\"refreshToken\":\"" + haru.refreshToken() + "\"}")).andExpect(status().isUnauthorized());
        mvc.perform(post("/api/v1/auth/login").contentType(MediaType.APPLICATION_JSON)
                .content("{\"email\":\"" + haru.email() + "\",\"password\":\"NewPassw0rd\"}"))
                .andExpect(status().isOk());
        assertThat(output.getOut()).contains("password_change").doesNotContain("NewPassw0rd");
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> syncFrom(Registered user, long lastSeq) throws Exception {
        String body = mvc.perform(post("/api/v1/sync").header("Authorization", user.bearer())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("lastSeq", lastSeq, "changes", List.of()))))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        return json.readValue(body, Map.class);
    }

    private static long nextSeq(Map<String, Object> body) {
        return ((Number) body.get("nextSeq")).longValue();
    }

    @Test
    @DisplayName("IT-MG-08 最後の1人が抜けると、同じ人の別の端末には全件の取り直しを指示する。取り直した後は指示しない")
    void 最後の1人_別の端末() throws Exception {
        leave(natsu, household, true);
        // 別の端末：抜ける前に最新まで同期してある
        long other = nextSeq(syncFrom(haru, 0));
        leave(haru, household, true).andExpect(jsonPath("$.householdDeleted").value(true));

        assertThat(syncFrom(haru, other).get("fullResyncRequired")).isEqualTo(true);
        Map<String, Object> again = syncFrom(haru, 0);
        assertThat(syncFrom(haru, nextSeq(again)).get("fullResyncRequired")).isEqualTo(false);
    }

    @Test
    @DisplayName("IT-MG-09 抜けると、そのおうちの項目のウィジェットのボタンに削除の印を付け、本人の端末へ届く。ほかのおうちのボタンは残す")
    void 抜けるとボタンを消す() throws Exception {
        UUID other = UUID.randomUUID();
        UUID otherType = UUID.randomUUID();
        mvc.perform(post("/api/v1/households").header("Authorization", natsu.bearer())
                .contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("id", other, "name", "なつ家", "recordTypes", List.of(
                        Map.of("id", otherType, "name", "水", "kind", "water", "sortOrder", 0))))))
                .andExpect(status().isCreated());
        UUID button = UUID.randomUUID();
        UUID kept = UUID.randomUUID();
        sync(natsu, List.of(
                change("widget_buttons", button, Map.of("recordTypeId", type.toString(), "sortOrder", 0)),
                change("widget_buttons", kept, Map.of("recordTypeId", otherType.toString(), "sortOrder", 1))));
        long before = nextSeq(syncFrom(natsu, 0));

        leave(natsu, household, true).andExpect(status().isOk());

        assertThat(jdbc.sql("SELECT deleted_at IS NOT NULL FROM widget_buttons WHERE id = :id").param("id", button)
                .query(Boolean.class).single()).isTrue();
        assertThat(jdbc.sql("SELECT deleted_at IS NULL FROM widget_buttons WHERE id = :id").param("id", kept)
                .query(Boolean.class).single()).isTrue();
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> changes = (List<Map<String, Object>>) syncFrom(natsu, before).get("changes");
        assertThat(changes).anySatisfy(c -> {
            assertThat(c.get("table")).isEqualTo("widget_buttons");
            assertThat(c.get("id")).isEqualTo(button.toString());
            assertThat(c.get("deletedAt")).isNotNull();
        });
    }
}
