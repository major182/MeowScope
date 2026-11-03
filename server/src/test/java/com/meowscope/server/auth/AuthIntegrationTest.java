package com.meowscope.server.auth;

import static com.meowscope.server.TestUsers.PASSWORD;
import static com.meowscope.server.TestUsers.json;
import static com.meowscope.server.TestUsers.quote;
import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import com.meowscope.server.IntegrationTest;
import com.meowscope.server.TestUsers;
import com.meowscope.server.TestUsers.Registered;
import java.time.Instant;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.system.CapturedOutput;
import org.springframework.boot.test.system.OutputCaptureExtension;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;

@IntegrationTest
@ExtendWith(OutputCaptureExtension.class)
class AuthIntegrationTest {

    @Autowired
    MockMvc mvc;

    @Autowired
    JdbcClient jdbc;

    @Autowired
    JwtEncoder encoder;

    private ResultActions postJson(String path, String body) throws Exception {
        return mvc.perform(post(path).contentType(MediaType.APPLICATION_JSON).content(body));
    }

    private ResultActions login(String email, String password) throws Exception {
        return postJson("/api/v1/auth/login", """
                {"email":%s,"password":%s}
                """.formatted(quote(email), quote(password)));
    }

    private ResultActions refresh(String token) throws Exception {
        return postJson("/api/v1/auth/refresh", "{\"refreshToken\":" + quote(token) + "}");
    }

    @Test
    @DisplayName("IT-AU-01 新規登録：201 でトークンと自分の情報を返し、メールアドレスを小文字で保存し、設定の行を作る")
    void 新規登録() throws Exception {
        String email = "Mixed" + TestUsers.uniqueEmail();
        String body = postJson("/api/v1/auth/register", json(email, PASSWORD, "  はる  "))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.accessToken").isNotEmpty())
                .andExpect(jsonPath("$.refreshToken").isNotEmpty())
                .andExpect(jsonPath("$.expiresIn").value(900))
                .andExpect(jsonPath("$.user.email").value(email.toLowerCase()))
                .andExpect(jsonPath("$.user.displayName").value("はる"))
                .andExpect(jsonPath("$.user.passwordHash").doesNotExist())
                .andReturn().getResponse().getContentAsString();
        String id = JsonPath.read(body, "$.user.id");
        String hash = jdbc.sql("SELECT password_hash FROM users WHERE id = ?::uuid").param(id)
                .query(String.class).single();
        assertThat(hash).startsWith("{bcrypt}").doesNotContain(PASSWORD);
        assertThat(jdbc.sql("SELECT week_start FROM user_settings WHERE user_id = ?::uuid").param(id)
                .query(String.class).single()).isEqualTo("sunday");
    }

    @Test
    @DisplayName("IT-AU-02 異常系：同じメールアドレス（大文字と小文字の違いを含む）は 409")
    void 重複() throws Exception {
        Registered user = TestUsers.register(mvc);
        postJson("/api/v1/auth/register", json(user.email().toUpperCase(), PASSWORD, "なつ"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("CONFLICT"));
    }

    @ParameterizedTest(name = "IT-AU-03 入力の検証：{3}")
    @CsvSource(delimiter = '|', textBlock = """
            ok@example.com      | Passw0rd       | はる | 201 | パスワード 8文字は可（境界値）
            ok@example.com      | Passw0r        | はる | 400 | パスワード 7文字は不可（境界値）
            ok@example.com      | aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa | はる | 201 | パスワード 64文字は可（境界値）
            ok@example.com      | aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa | はる | 400 | パスワード 65文字は不可（境界値）
            ok@example.com      | Ｐassw0rd!     | はる | 400 | パスワードに全角は不可（BR-26）
            ok@example.com      | Pass w0rd      | はる | 400 | パスワードに空白は不可
            ｏk@example.com     | Passw0rd!      | はる | 400 | メールアドレスに全角は不可（BR-26）
            not-an-email        | Passw0rd!      | はる | 400 | メールアドレスの形でない
            ok@example.com      | Passw0rd!      | '  ' | 400 | 表示名が空白だけ
            ok@example.com      | Passw0rd!      | 一二三四五六七八九十一二三四五六七八九十 | 201 | 表示名 20文字は可（境界値）
            ok@example.com      | Passw0rd!      | 一二三四五六七八九十一二三四五六七八九十一 | 400 | 表示名 21文字は不可（境界値）
            """)
    void 入力の検証(String email, String password, String name, int expected, String label) throws Exception {
        // 201 になる行どうしがぶつからないよう、メールアドレスの前に毎回違う文字を付ける
        String unique = email.contains("@") ? TestUsers.uniqueEmail().split("@")[0] + email : email;
        postJson("/api/v1/auth/register", json(unique, password, name))
                .andExpect(status().is(expected));
    }

    @Test
    @DisplayName("IT-AU-04 異常系：本文が JSON でなければ 400")
    void 壊れた本文() throws Exception {
        postJson("/api/v1/auth/register", "{")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
    }

    @Test
    @DisplayName("IT-AU-05 ログイン：正しければトークンを返す。メールアドレスの大文字と小文字は区別しない")
    void ログイン() throws Exception {
        Registered user = TestUsers.register(mvc);
        login(user.email().toUpperCase(), PASSWORD)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.user.id").value(user.id().toString()))
                .andExpect(jsonPath("$.accessToken").isNotEmpty());
    }

    @Test
    @DisplayName("IT-AU-06 異常系：パスワードの誤りと、登録のないメールアドレスは、同じ 401")
    void ログインの失敗() throws Exception {
        Registered user = TestUsers.register(mvc);
        login(user.email(), "wrong-password").andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
        login(TestUsers.uniqueEmail(), PASSWORD).andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
    }

    @Test
    @DisplayName("IT-AU-07 回数制限：4回の失敗までは試せ、5回目の失敗の後は正しいパスワードでも 429（NF-SC-03）")
    void 回数制限() throws Exception {
        Registered user = TestUsers.register(mvc);
        for (int i = 0; i < 4; i++) {
            login(user.email(), "wrong-password").andExpect(status().isUnauthorized());
        }
        // 4回の失敗の後は、まだ正しいパスワードで入れる。成功すると数え直す
        login(user.email(), PASSWORD).andExpect(status().isOk());
        for (int i = 0; i < 5; i++) {
            login(user.email(), "wrong-password").andExpect(status().isUnauthorized());
        }
        login(user.email(), PASSWORD).andExpect(status().isTooManyRequests())
                .andExpect(jsonPath("$.code").value("TOO_MANY_REQUESTS"));
    }

    @Test
    @DisplayName("IT-AU-08 更新：新しい組に交換し、古い更新トークンは使えなくなる")
    void 更新() throws Exception {
        Registered user = TestUsers.register(mvc);
        String body = refresh(user.refreshToken()).andExpect(status().isOk())
                .andExpect(jsonPath("$.user.id").value(user.id().toString()))
                .andReturn().getResponse().getContentAsString();
        String next = JsonPath.read(body, "$.refreshToken");
        assertThat(next).isNotEqualTo(user.refreshToken());
        refresh(next).andExpect(status().isOk());
    }

    @Test
    @DisplayName("IT-AU-09 使い回しの検知：使い終わった更新トークンが来たら、そのユーザーの全トークンを無効にし、alert を出す")
    void 使い回し(CapturedOutput output) throws Exception {
        Registered user = TestUsers.register(mvc);
        String body = refresh(user.refreshToken()).andReturn().getResponse().getContentAsString();
        String next = JsonPath.read(body, "$.refreshToken");

        refresh(user.refreshToken()).andExpect(status().isUnauthorized());

        // 正しい持ち主の新しいトークンも無効になっている
        refresh(next).andExpect(status().isUnauthorized());
        assertThat(output).contains("\"status\":\"alert\"").contains("refresh_token_reuse");
    }

    @Test
    @DisplayName("IT-AU-10 異常系：期限切れ・知らない更新トークンは 401")
    void 期限切れの更新トークン() throws Exception {
        Registered user = TestUsers.register(mvc);
        jdbc.sql("UPDATE refresh_tokens SET expires_at = now() - interval '1 second' WHERE user_id = :id")
                .param("id", user.id()).update();
        refresh(user.refreshToken()).andExpect(status().isUnauthorized());
        refresh("unknown-token").andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("IT-AU-11 ログアウト：204 で、その更新トークンは使えなくなる。認証なしでは 401")
    void ログアウト() throws Exception {
        Registered user = TestUsers.register(mvc);
        String body = "{\"refreshToken\":" + quote(user.refreshToken()) + "}";
        mvc.perform(post("/api/v1/auth/logout").contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isUnauthorized());
        mvc.perform(post("/api/v1/auth/logout").header("Authorization", user.bearer())
                        .contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isNoContent());
        refresh(user.refreshToken()).andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("IT-AU-12 自分の情報：取得と表示名の変更。変更で通し番号が進む")
    void 自分の情報() throws Exception {
        Registered user = TestUsers.register(mvc);
        mvc.perform(get("/api/v1/me").header("Authorization", user.bearer()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.email").value(user.email()))
                .andExpect(jsonPath("$.displayName").value("はる"));
        long before = seq(user);
        mvc.perform(patch("/api/v1/me").header("Authorization", user.bearer())
                        .contentType(MediaType.APPLICATION_JSON).content("{\"displayName\":\" なつ \"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.displayName").value("なつ"));
        assertThat(seq(user)).isGreaterThan(before);
        mvc.perform(patch("/api/v1/me").header("Authorization", user.bearer())
                        .contentType(MediaType.APPLICATION_JSON).content("{\"displayName\":\"\"}"))
                .andExpect(status().isBadRequest());
    }

    private long seq(Registered user) {
        return jdbc.sql("SELECT server_seq FROM users WHERE id = :id").param("id", user.id())
                .query(Long.class).single();
    }

    @Test
    @DisplayName("IT-AU-13 アクセストークン：なし・壊れている・期限切れ・別の鍵で署名は 401、消えたユーザーも 401")
    void アクセストークンの検証() throws Exception {
        mvc.perform(get("/api/v1/me")).andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
        mvc.perform(get("/api/v1/me").header("Authorization", "Bearer broken"))
                .andExpect(status().isUnauthorized());

        Registered user = TestUsers.register(mvc);
        Instant past = Instant.now().minusSeconds(3600);
        JwtClaimsSet expired = JwtClaimsSet.builder().subject(user.id().toString())
                .issuedAt(past).expiresAt(past.plusSeconds(900)).build();
        String token = encoder.encode(JwtEncoderParameters.from(JwsHeader.with(MacAlgorithm.HS256).build(), expired))
                .getTokenValue();
        mvc.perform(get("/api/v1/me").header("Authorization", "Bearer " + token))
                .andExpect(status().isUnauthorized());

        // 署名の部分だけを差し替えたトークン（別の鍵で作ったものと同じく、検証で弾かれる）
        String[] parts = user.accessToken().split("\\.");
        String forged = parts[0] + "." + parts[1] + ".AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";
        mvc.perform(get("/api/v1/me").header("Authorization", "Bearer " + forged))
                .andExpect(status().isUnauthorized());

        jdbc.sql("DELETE FROM users WHERE id = :id").param("id", user.id()).update();
        mvc.perform(get("/api/v1/me").header("Authorization", user.bearer()))
                .andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("IT-AU-14 ログにパスワード・トークン・メールアドレスを出さず、利用者の ID を出す（ログ設計書 6章）")
    void ログに秘密を出さない(CapturedOutput output) throws Exception {
        Registered user = TestUsers.register(mvc);
        login(user.email(), "wrong-password-xyz");
        mvc.perform(get("/api/v1/me").header("Authorization", user.bearer()));
        postJson("/api/v1/auth/register", json(TestUsers.uniqueEmail(), "short", "x"));
        assertThat(output.getOut())
                .doesNotContain(PASSWORD)
                .doesNotContain("wrong-password-xyz")
                .doesNotContain("\"short\"")
                .doesNotContain(user.accessToken())
                .doesNotContain(user.refreshToken())
                .doesNotContain(user.email())
                .contains("\"usr\":{\"id\":\"" + user.id() + "\"}")
                .contains("\"status\":\"notice\"");
    }
}
