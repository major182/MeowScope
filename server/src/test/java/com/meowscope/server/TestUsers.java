package com.meowscope.server;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import java.util.UUID;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

/** 結合テストで、API を通してユーザーを作り、トークンを受け取る。 */
public final class TestUsers {

    public static final String PASSWORD = "Passw0rd!";

    private TestUsers() {
    }

    /** 登録したユーザー。 */
    public record Registered(UUID id, String email, String accessToken, String refreshToken) {

        public String bearer() {
            return "Bearer " + accessToken;
        }
    }

    /** 他のテストとぶつからないメールアドレス。 */
    public static String uniqueEmail() {
        return "u" + UUID.randomUUID().toString().replace("-", "") + "@example.com";
    }

    public static Registered register(MockMvc mvc) throws Exception {
        return register(mvc, uniqueEmail(), "はる");
    }

    public static Registered register(MockMvc mvc, String email, String name) throws Exception {
        String body = mvc.perform(post("/api/v1/auth/register").contentType(MediaType.APPLICATION_JSON)
                        .content(json(email, PASSWORD, name)))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        return new Registered(UUID.fromString(JsonPath.read(body, "$.user.id")), email,
                JsonPath.read(body, "$.accessToken"), JsonPath.read(body, "$.refreshToken"));
    }

    public static String json(String email, String password, String displayName) {
        return """
                {"email":%s,"password":%s,"displayName":%s}
                """.formatted(quote(email), quote(password), quote(displayName));
    }

    public static String quote(String value) {
        return value == null ? "null" : "\"" + value.replace("\\", "\\\\").replace("\"", "\\\"") + "\"";
    }
}
