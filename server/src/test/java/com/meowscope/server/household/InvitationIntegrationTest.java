package com.meowscope.server.household;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import com.meowscope.server.IntegrationTest;
import com.meowscope.server.TestUsers;
import com.meowscope.server.TestUsers.Registered;
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
class InvitationIntegrationTest {

    @Autowired
    MockMvc mvc;

    @Autowired
    JdbcClient jdbc;

    @Autowired
    JsonMapper json;

    Registered haru;
    UUID household;

    @BeforeEach
    void setUp() throws Exception {
        haru = TestUsers.register(mvc);
        household = UUID.randomUUID();
        mvc.perform(post("/api/v1/households").header("Authorization", haru.bearer())
                .contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("id", household, "name", "みけ家", "recordTypes", List.of()))))
                .andExpect(status().isCreated());
    }

    private String invite(Registered user) throws Exception {
        String body = mvc.perform(post("/api/v1/households/" + household + "/invitations")
                        .header("Authorization", user.bearer()))
                .andExpect(status().isCreated()).andReturn().getResponse().getContentAsString();
        return JsonPath.read(body, "$.token");
    }

    private ResultActions accept(Registered user, String token) throws Exception {
        return mvc.perform(post("/api/v1/invitations/accept").header("Authorization", user.bearer())
                .contentType(MediaType.APPLICATION_JSON).content("{\"token\":\"" + token + "\"}"));
    }

    private boolean member(Registered user) {
        return jdbc.sql("SELECT count(*) FROM household_members WHERE household_id = :h AND user_id = :u"
                + " AND deleted_at IS NULL").param("h", household).param("u", user.id())
                .query(Long.class).single() > 0;
    }

    @Test
    @DisplayName("IT-IV-01 招待のリンクを作り、受けた人がメンバーになる。リンクは meowscope:// の形で、ハッシュだけを保存する")
    void 参加(CapturedOutput output) throws Exception {
        String body = mvc.perform(post("/api/v1/households/" + household + "/invitations")
                        .header("Authorization", haru.bearer()))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.expiresAt").isNotEmpty())
                .andReturn().getResponse().getContentAsString();
        String token = JsonPath.read(body, "$.token");
        assertThat((String) JsonPath.read(body, "$.link")).isEqualTo("meowscope://invite?token=" + token);
        assertThat(jdbc.sql("SELECT count(*) FROM invitations WHERE token_hash = :t").param("t", token)
                .query(Long.class).single()).isZero();

        Registered natsu = TestUsers.register(mvc);
        accept(natsu, token).andExpect(status().isOk()).andExpect(jsonPath("$.householdId").value(household.toString()));
        assertThat(member(natsu)).isTrue();
        assertThat(output.getOut()).contains("invitation_accept").doesNotContain(token);
    }

    @Test
    @DisplayName("IT-IV-02 1回だけ：使ったリンクは別の人も使えない（404）")
    void 一回だけ() throws Exception {
        String token = invite(haru);
        accept(TestUsers.register(mvc), token).andExpect(status().isOk());
        Registered third = TestUsers.register(mvc);
        accept(third, token).andExpect(status().isNotFound());
        assertThat(member(third)).isFalse();
    }

    @Test
    @DisplayName("IT-IV-03 期限の境界値：1時間を過ぎたら 404、その直前は使える")
    void 期限() throws Exception {
        String expired = invite(haru);
        String almost = invite(haru);
        jdbc.sql("UPDATE invitations SET expires_at = now() - interval '1 second' WHERE token_hash = :h")
                .param("h", InvitationService.hash(expired)).update();
        jdbc.sql("UPDATE invitations SET expires_at = now() + interval '5 second' WHERE token_hash = :h")
                .param("h", InvitationService.hash(almost)).update();
        accept(TestUsers.register(mvc), expired).andExpect(status().isNotFound());
        accept(TestUsers.register(mvc), almost).andExpect(status().isOk());
    }

    @Test
    @DisplayName("IT-IV-04 異常系：メンバーでない人は作れない（404）。知らないリンク・空は 404・400。すでにメンバーなら重複させない")
    void 異常系() throws Exception {
        Registered other = TestUsers.register(mvc);
        mvc.perform(post("/api/v1/households/" + household + "/invitations").header("Authorization", other.bearer()))
                .andExpect(status().isNotFound());
        accept(other, "unknown").andExpect(status().isNotFound());
        accept(other, "").andExpect(status().isBadRequest());
        accept(haru, invite(haru)).andExpect(status().isOk());
        assertThat(jdbc.sql("SELECT count(*) FROM household_members WHERE household_id = :h AND user_id = :u")
                .param("h", household).param("u", haru.id()).query(Long.class).single()).isEqualTo(1);
    }

    @Test
    @DisplayName("IT-IV-05 新しく加わった人のユーザーの行（表示名・アイコンの有無）が、前からいるメンバーの差分の同期に届く")
    void 加わった人が届く() throws Exception {
        Registered natsu = TestUsers.register(mvc);
        String sync = "{\"lastSeq\":0,\"changes\":[]}";
        String first = mvc.perform(post("/api/v1/sync").header("Authorization", haru.bearer())
                .contentType(MediaType.APPLICATION_JSON).content(sync)).andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        long seq = ((Number) JsonPath.read(first, "$.nextSeq")).longValue();

        accept(natsu, invite(haru)).andExpect(status().isOk());

        String body = mvc.perform(post("/api/v1/sync").header("Authorization", haru.bearer())
                .contentType(MediaType.APPLICATION_JSON).content("{\"lastSeq\":" + seq + ",\"changes\":[]}"))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        List<String> users = JsonPath.read(body, "$.changes[?(@.table == 'users')].id");
        assertThat(users).contains(natsu.id().toString());
    }

    @Test
    @DisplayName("IT-IV-06 すでにメンバーの人が招待を受けても、リンクは使用済みにならず、ほかの人が使える")
    void メンバーが受けても使える() throws Exception {
        String token = invite(haru);
        accept(haru, token).andExpect(status().isOk());
        Registered natsu = TestUsers.register(mvc);
        accept(natsu, token).andExpect(status().isOk());
        assertThat(member(natsu)).isTrue();
    }
}
