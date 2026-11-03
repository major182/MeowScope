package com.meowscope.server.icon;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.meowscope.server.IntegrationTest;
import com.meowscope.server.TestUsers;
import com.meowscope.server.TestUsers.Registered;
import java.util.Arrays;
import java.util.LinkedHashMap;
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
import org.springframework.test.web.servlet.ResultActions;
import tools.jackson.databind.json.JsonMapper;

@IntegrationTest
class IconIntegrationTest {

    static final byte[] JPEG = {(byte) 0xFF, (byte) 0xD8, (byte) 0xFF, (byte) 0xE0, 9, 9};

    @Autowired
    MockMvc mvc;

    @Autowired
    JdbcClient jdbc;

    @Autowired
    JsonMapper json;

    Registered haru;
    Registered natsu;
    UUID household;
    UUID cat;

    @BeforeEach
    void setUp() throws Exception {
        haru = TestUsers.register(mvc);
        natsu = TestUsers.register(mvc);
        household = UUID.randomUUID();
        cat = UUID.randomUUID();
        mvc.perform(post("/api/v1/households").header("Authorization", haru.bearer())
                .contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("id", household, "name", "みけ家", "recordTypes", List.of()))));
        jdbc.sql("INSERT INTO household_members (id, household_id, user_id) VALUES (gen_random_uuid(), :h, :u)")
                .param("h", household).param("u", natsu.id()).update();
        Map<String, Object> change = new LinkedHashMap<>();
        change.put("table", "cats");
        change.put("id", cat);
        change.put("updatedAt", "2026-11-03T00:00:00Z");
        change.put("deletedAt", null);
        change.put("data", Map.of("householdId", household.toString(), "name", "ミケ", "status", "active"));
        mvc.perform(post("/api/v1/sync").header("Authorization", haru.bearer()).contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("lastSeq", 0, "changes", List.of(change)))));
    }

    private ResultActions putIcon(Registered user, String path, byte[] bytes) throws Exception {
        return mvc.perform(put(path).header("Authorization", user.bearer()).contentType(MediaType.IMAGE_JPEG)
                .content(bytes));
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> pulled(Registered user, String table, UUID id) throws Exception {
        String body = mvc.perform(post("/api/v1/sync").header("Authorization", user.bearer())
                        .contentType(MediaType.APPLICATION_JSON).content("{\"lastSeq\":0,\"changes\":[]}"))
                .andReturn().getResponse().getContentAsString();
        List<Map<String, Object>> changes = (List<Map<String, Object>>) json.readValue(body, Map.class).get("changes");
        return (Map<String, Object>) changes.stream()
                .filter(c -> c.get("table").equals(table) && c.get("id").equals(id.toString()))
                .findFirst().orElseThrow().get("data");
    }

    @Test
    @DisplayName("IT-IC-01 自分のアイコンを送ると、同じおうちの人が取得でき、同期でアイコンありと届く")
    void ユーザーのアイコン() throws Exception {
        assertThat(pulled(natsu, "users", haru.id())).containsEntry("hasIcon", false);
        putIcon(haru, "/api/v1/me/icon", JPEG).andExpect(status().isNoContent());

        mvc.perform(get("/api/v1/users/" + haru.id() + "/icon").header("Authorization", natsu.bearer()))
                .andExpect(status().isOk()).andExpect(content().bytes(JPEG));
        assertThat(pulled(natsu, "users", haru.id())).containsEntry("hasIcon", true);
    }

    @Test
    @DisplayName("IT-IC-02 猫のアイコンを送ると、同じおうちの人が取得でき、同期でアイコンありと届く")
    void 猫のアイコン() throws Exception {
        putIcon(natsu, "/api/v1/cats/" + cat + "/icon", JPEG).andExpect(status().isNoContent());
        mvc.perform(get("/api/v1/cats/" + cat + "/icon").header("Authorization", haru.bearer()))
                .andExpect(status().isOk()).andExpect(content().bytes(JPEG));
        assertThat(pulled(haru, "cats", cat)).containsEntry("hasIcon", true);
    }

    @Test
    @DisplayName("IT-IC-03 権限：おうちの違う人は取得も送信も 404。アイコンがなければ 404")
    void 権限() throws Exception {
        Registered other = TestUsers.register(mvc);
        mvc.perform(get("/api/v1/users/" + haru.id() + "/icon").header("Authorization", haru.bearer()))
                .andExpect(status().isNotFound());
        putIcon(haru, "/api/v1/me/icon", JPEG);
        mvc.perform(get("/api/v1/users/" + haru.id() + "/icon").header("Authorization", other.bearer()))
                .andExpect(status().isNotFound());
        putIcon(other, "/api/v1/cats/" + cat + "/icon", JPEG).andExpect(status().isNotFound());
        mvc.perform(get("/api/v1/cats/" + cat + "/icon").header("Authorization", other.bearer()))
                .andExpect(status().isNotFound());
        putIcon(haru, "/api/v1/cats/" + UUID.randomUUID() + "/icon", JPEG).andExpect(status().isNotFound());
    }

    @Test
    @DisplayName("IT-IC-04 容量の境界値：1MB は可、1バイト超えると 413。画像でなければ 415")
    void 容量と形式() throws Exception {
        putIcon(haru, "/api/v1/me/icon", Arrays.copyOf(JPEG, IconService.MAX_BYTES)).andExpect(status().isNoContent());
        putIcon(haru, "/api/v1/me/icon", Arrays.copyOf(JPEG, IconService.MAX_BYTES + 1))
                .andExpect(status().isPayloadTooLarge());
        putIcon(haru, "/api/v1/me/icon", "text".getBytes()).andExpect(status().isUnsupportedMediaType());
    }
}
