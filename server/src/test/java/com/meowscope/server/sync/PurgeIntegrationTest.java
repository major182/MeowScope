package com.meowscope.server.sync;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.meowscope.server.IntegrationTest;
import com.meowscope.server.TestUsers;
import com.meowscope.server.TestUsers.Registered;
import com.meowscope.server.photo.PhotoStorage;
import java.io.IOException;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.test.web.servlet.MockMvc;
import tools.jackson.databind.json.JsonMapper;

@IntegrationTest
class PurgeIntegrationTest {

    @Autowired
    MockMvc mvc;

    @Autowired
    JdbcClient jdbc;

    @Autowired
    JsonMapper json;

    @Autowired
    PurgeService purge;

    @Autowired
    PhotoStorage storage;

    Registered haru;
    UUID household;
    UUID food;
    UUID cat;

    @BeforeEach
    void setUp() throws Exception {
        haru = TestUsers.register(mvc);
        household = UUID.randomUUID();
        food = UUID.randomUUID();
        cat = UUID.randomUUID();
        String body = json.writeValueAsString(Map.of("id", household, "name", "みけ家", "recordTypes", List.of(
                Map.of("id", food, "name", "ご飯", "icon", "food", "kind", "food", "sortOrder", 0))));
        mvc.perform(post("/api/v1/households").header("Authorization", haru.bearer())
                .contentType(MediaType.APPLICATION_JSON).content(body)).andExpect(status().isCreated());
        jdbc.sql("INSERT INTO cats (id, household_id, name, status) VALUES (:id, :h, 'ミケ', 'active')")
                .param("id", cat).param("h", household).update();
    }

    /** 記録を作り、[daysAgo] 日前に削除の印を付ける（null なら削除しない）。テストの側で DB を直接書く。 */
    private UUID record(Integer daysAgo) {
        UUID id = UUID.randomUUID();
        jdbc.sql("""
                INSERT INTO records (id, cat_id, record_type_id, recorded_at, author_id, author_name, deleted_at)
                VALUES (:id, :cat, :type, now(), :user, 'はる',
                  CASE WHEN CAST(:days AS integer) IS NULL THEN NULL
                       ELSE now() - make_interval(days => CAST(:days AS integer)) END)
                """).param("id", id).param("cat", cat).param("type", food).param("user", haru.id())
                .param("days", daysAgo).update();
        return id;
    }

    private boolean exists(String table, UUID id) {
        return jdbc.sql("SELECT count(*) FROM " + table + " WHERE id = :id").param("id", id).query(Long.class)
                .single() > 0;
    }

    private long seqOf(String table, UUID id) {
        return jdbc.sql("SELECT server_seq FROM " + table + " WHERE id = :id").param("id", id).query(Long.class)
                .single();
    }

    @SuppressWarnings("unchecked")
    private boolean fullResync(long lastSeq) throws Exception {
        String body = mvc.perform(post("/api/v1/sync").header("Authorization", haru.bearer())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("lastSeq", lastSeq, "changes", List.of()))))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        return (Boolean) json.readValue(body, Map.class).get("fullResyncRequired");
    }

    @Test
    @DisplayName("IT-PG-01 境界値：削除から91日の行は消し、89日の行と削除していない行は残す")
    void 期間() {
        UUID old = record(91);
        UUID recent = record(89);
        UUID alive = record(null);

        int count = purge.purge();

        assertThat(count).isGreaterThanOrEqualTo(1);
        assertThat(exists("records", old)).isFalse();
        assertThat(exists("records", recent)).isTrue();
        assertThat(exists("records", alive)).isTrue();
    }

    @Test
    @DisplayName("IT-PG-02 写真は行と一緒にサーバーのファイルも消す。猫を消すと、その記録も消える")
    void 写真と猫() {
        UUID rec = record(91);
        UUID photo = UUID.randomUUID();
        String path = storage.saveAt("purge-test/" + photo, new byte[] {1, 2, 3});
        jdbc.sql("""
                INSERT INTO record_photos (id, record_id, sort_order, file_path, deleted_at)
                VALUES (:id, :rec, 1, :path, now() - interval '91 days')
                """).param("id", photo).param("rec", rec).param("path", path).update();
        UUID kept = record(null);
        jdbc.sql("UPDATE cats SET deleted_at = now() - interval '91 days' WHERE id = :id").param("id", cat).update();

        purge.purge();

        assertThat(exists("record_photos", photo)).isFalse();
        assertThatThrownBy(() -> storage.load(path)).isInstanceOf(IOException.class);
        assertThat(exists("cats", cat)).isFalse();
        assertThat(exists("records", kept)).isFalse();
    }

    @Test
    @DisplayName("IT-PG-03 消した行より前の位置から同期した端末には全件の取り直しを指示し、消した行の位置からなら指示しない")
    void 全件の取り直し() throws Exception {
        UUID old = record(91);
        long seq = seqOf("records", old);
        assertThat(fullResync(seq - 1)).isFalse();

        purge.purge();

        assertThat(fullResync(seq - 1)).isTrue();
        assertThat(fullResync(seq)).isFalse();
        // はじめての同期（位置 0）は、もともと全件を受け取るので指示しない
        assertThat(fullResync(0)).isFalse();
    }

    @Test
    @DisplayName("IT-PG-04 片付け：90日より前に期限の切れたログインのトークン・招待と、期限の切れた確認コードを消す。新しいものは残す")
    void 片付け() {
        UUID oldToken = UUID.randomUUID();
        UUID newToken = UUID.randomUUID();
        jdbc.sql("""
                INSERT INTO refresh_tokens (id, user_id, token_hash, expires_at)
                VALUES (:old, :u, :h1, now() - interval '91 days'), (:new, :u, :h2, now() + interval '1 day')
                """).param("old", oldToken).param("new", newToken).param("u", haru.id())
                .param("h1", "old-" + oldToken).param("h2", "new-" + newToken).update();
        UUID oldInvite = UUID.randomUUID();
        jdbc.sql("""
                INSERT INTO invitations (id, household_id, token_hash, expires_at)
                VALUES (:id, :h, :hash, now() - interval '91 days')
                """).param("id", oldInvite).param("h", household).param("hash", "x-" + oldInvite).update();
        jdbc.sql("""
                INSERT INTO password_resets (user_id, code_hash, expires_at)
                VALUES (:u, 'x', now() - interval '1 minute')
                """).param("u", haru.id()).update();

        purge.purge();

        assertThat(exists("refresh_tokens", oldToken)).isFalse();
        assertThat(exists("refresh_tokens", newToken)).isTrue();
        assertThat(exists("invitations", oldInvite)).isFalse();
        assertThat(jdbc.sql("SELECT count(*) FROM password_resets WHERE user_id = :u").param("u", haru.id())
                .query(Long.class).single()).isZero();
    }
}
