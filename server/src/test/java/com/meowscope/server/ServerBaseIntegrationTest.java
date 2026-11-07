package com.meowscope.server;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.test.web.servlet.MockMvc;

@IntegrationTest
class ServerBaseIntegrationTest {

    @Autowired
    MockMvc mvc;

    @Autowired
    JdbcClient jdbc;

    @Test
    @DisplayName("IT-DB-01 Flyway で DB 設計書の表がすべてできる")
    void 表がすべてできる() {
        List<String> tables = jdbc.sql("""
                SELECT table_name FROM information_schema.tables
                WHERE table_schema = 'public' AND table_name <> 'flyway_schema_history'
                """).query(String.class).list();
        assertThat(tables).containsExactlyInAnyOrder("users", "user_settings", "households", "household_members",
                "cats", "record_types", "records", "record_photos", "widget_buttons", "medication_schedules", "invitations",
                "refresh_tokens", "password_resets", "sync_purges");
    }

    @Test
    @DisplayName("IT-DB-02 記録項目は非表示の列を持ち、既定は表示")
    void 記録項目の非表示の既定() {
        String householdId = "00000000-0000-0000-0000-000000000001";
        jdbc.sql("INSERT INTO households (id, name) VALUES (?::uuid, 'うち')").param(householdId).update();
        jdbc.sql("INSERT INTO record_types (id, household_id, name, kind) VALUES (gen_random_uuid(), ?::uuid, 'ご飯', 'food')")
                .param(householdId).update();
        Boolean hidden = jdbc.sql("SELECT hidden FROM record_types WHERE household_id = ?::uuid")
                .param(householdId).query(Boolean.class).single();
        assertThat(hidden).isFalse();
    }

    @Test
    @DisplayName("IT-DB-03 変更のたびに server_seq が増える")
    void 通し番号が増える() {
        jdbc.sql("INSERT INTO households (id, name) VALUES (gen_random_uuid(), 'a'), (gen_random_uuid(), 'b')").update();
        List<Long> seqs = jdbc.sql("SELECT server_seq FROM households WHERE name IN ('a', 'b') ORDER BY server_seq")
                .query(Long.class).list();
        assertThat(seqs.get(1)).isGreaterThan(seqs.get(0));
    }

    @Test
    @DisplayName("IT-ER-01 存在しないパスは RFC 9457 の形で 404 を返し、問い合わせ番号を付ける")
    void 存在しないパス() throws Exception {
        TestUsers.Registered user = TestUsers.register(mvc);
        mvc.perform(get("/api/v1/nothing").header("X-Request-Id", "req-123").header("Authorization", user.bearer()))
                .andExpect(status().isNotFound())
                .andExpect(header().string("X-Request-Id", "req-123"))
                .andExpect(header().string("Content-Type", MediaType.APPLICATION_PROBLEM_JSON_VALUE))
                .andExpect(jsonPath("$.status").value(404))
                .andExpect(jsonPath("$.code").value("NOT_FOUND"))
                .andExpect(jsonPath("$.title").value("見つかりません"))
                .andExpect(jsonPath("$.requestId").value("req-123"));
    }

    @Test
    @DisplayName("IT-ER-02 死活監視は UP を返し、詳しい情報は出さない")
    void 死活監視() throws Exception {
        mvc.perform(get("/actuator/health"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("UP"))
                .andExpect(jsonPath("$.components").doesNotExist());
    }
}
