package com.meowscope.server.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.meowscope.server.IntegrationTest;
import com.meowscope.server.TestUsers;
import com.meowscope.server.TestUsers.Registered;
import com.meowscope.server.mail.PasswordResetMailer;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.test.system.CapturedOutput;
import org.springframework.boot.test.system.OutputCaptureExtension;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.context.annotation.Primary;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;

@IntegrationTest
@Import(PasswordResetIntegrationTest.MailConfig.class)
@ExtendWith(OutputCaptureExtension.class)
class PasswordResetIntegrationTest {

    /** 送ったメールを覚えておく（テストの側の差し替え。本物の SMTP には送らない）。 */
    static final class CapturingMailer implements PasswordResetMailer {
        record Sent(String to, String code, Duration validFor) {
        }

        final List<Sent> sent = new ArrayList<>();
        boolean fail;

        @Override
        public synchronized void sendCode(String to, String code, Duration validFor) {
            if (fail) {
                throw new MailException("テストで送れなくした", null);
            }
            sent.add(new Sent(to, code, validFor));
        }

        synchronized String lastCodeTo(String to) {
            return sent.stream().filter(s -> s.to().equals(to)).reduce((a, b) -> b).orElseThrow().code();
        }

        synchronized long countTo(String to) {
            return sent.stream().filter(s -> s.to().equals(to)).count();
        }
    }

    @TestConfiguration
    static class MailConfig {
        @Bean
        @Primary
        CapturingMailer capturingMailer() {
            return new CapturingMailer();
        }
    }

    @Autowired
    MockMvc mvc;

    @Autowired
    JdbcClient jdbc;

    @Autowired
    CapturingMailer mailer;

    Registered haru;

    @BeforeEach
    void setUp() throws Exception {
        mailer.fail = false;
        haru = TestUsers.register(mvc);
    }

    private ResultActions request(String email) throws Exception {
        return mvc.perform(post("/api/v1/auth/password-reset/request").contentType(MediaType.APPLICATION_JSON)
                .content("{\"email\":" + TestUsers.quote(email) + "}"));
    }

    private ResultActions confirm(String email, String code, String password) throws Exception {
        return mvc.perform(post("/api/v1/auth/password-reset/confirm").contentType(MediaType.APPLICATION_JSON)
                .content("{\"email\":%s,\"code\":%s,\"newPassword\":%s}".formatted(TestUsers.quote(email),
                        TestUsers.quote(code), TestUsers.quote(password))));
    }

    private ResultActions login(String email, String password) throws Exception {
        return mvc.perform(post("/api/v1/auth/login").contentType(MediaType.APPLICATION_JSON)
                .content(TestUsers.json(email, password, null)));
    }

    /** 送り直しの間隔を待たずに済むよう、前の受付の時刻を戻す（テストの側の操作）。 */
    private void allowResend(Registered user) {
        jdbc.sql("UPDATE password_resets SET created_at = created_at - interval '2 minutes' WHERE user_id = :id")
                .param("id", user.id()).update();
    }

    private String wrong(String code) {
        return code.equals("000000") ? "000001" : "000000";
    }

    @Test
    @DisplayName("IT-PR-01 受付で6桁のコードを15分の期限で送り、コードと新しいパスワードで変えるとログインした状態になる。"
            + "古いパスワード・ほかの端末のログインは使えなくなる。メールアドレスは大文字でもよい")
    void 再設定() throws Exception {
        request(haru.email().toUpperCase()).andExpect(status().isAccepted());
        String code = mailer.lastCodeTo(haru.email());
        assertThat(code).matches("[0-9]{6}");
        assertThat(mailer.sent.getLast().validFor()).isEqualTo(Duration.ofMinutes(15));

        confirm(haru.email(), code, "NewPassw0rd!").andExpect(status().isOk())
                .andExpect(jsonPath("$.user.id").value(haru.id().toString()))
                .andExpect(jsonPath("$.accessToken").isNotEmpty());

        login(haru.email(), TestUsers.PASSWORD).andExpect(status().isUnauthorized());
        login(haru.email(), "NewPassw0rd!").andExpect(status().isOk());
        mvc.perform(post("/api/v1/auth/refresh").contentType(MediaType.APPLICATION_JSON)
                .content("{\"refreshToken\":" + TestUsers.quote(haru.refreshToken()) + "}"))
                .andExpect(status().isUnauthorized());
        // 使ったコードはもう使えない
        confirm(haru.email(), code, "Another1!").andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_RESET_CODE"));
    }

    @Test
    @DisplayName("IT-PR-02 登録されていないメールアドレスでも 202 で、メールは送らない（登録の有無を知られない）。"
            + "そのメールアドレスでの実行は 400")
    void 登録されていない() throws Exception {
        String email = TestUsers.uniqueEmail();
        request(email).andExpect(status().isAccepted());
        assertThat(mailer.countTo(email)).isZero();
        confirm(email, "123456", "NewPassw0rd!").andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_RESET_CODE"));
    }

    @Test
    @DisplayName("IT-PR-03 境界値：コードを4回間違えても正しいコードで変えられる。5回目の間違いでコードが使えなくなる")
    void 間違いの回数() throws Exception {
        request(haru.email()).andExpect(status().isAccepted());
        String code = mailer.lastCodeTo(haru.email());
        for (int i = 0; i < 4; i++) {
            confirm(haru.email(), wrong(code), "NewPassw0rd!").andExpect(status().isBadRequest());
        }
        confirm(haru.email(), code, "NewPassw0rd!").andExpect(status().isOk());

        Registered aki = TestUsers.register(mvc);
        request(aki.email()).andExpect(status().isAccepted());
        String akiCode = mailer.lastCodeTo(aki.email());
        for (int i = 0; i < 5; i++) {
            confirm(aki.email(), wrong(akiCode), "NewPassw0rd!").andExpect(status().isBadRequest());
        }
        confirm(aki.email(), akiCode, "NewPassw0rd!").andExpect(status().isBadRequest());
    }

    @Test
    @DisplayName("IT-PR-04 境界値：期限の直前は使え、期限を過ぎたら 400")
    void 期限() throws Exception {
        request(haru.email()).andExpect(status().isAccepted());
        String code = mailer.lastCodeTo(haru.email());
        jdbc.sql("UPDATE password_resets SET expires_at = now() - interval '1 second' WHERE user_id = :id")
                .param("id", haru.id()).update();
        confirm(haru.email(), code, "NewPassw0rd!").andExpect(status().isBadRequest());

        allowResend(haru);
        request(haru.email()).andExpect(status().isAccepted());
        String next = mailer.lastCodeTo(haru.email());
        jdbc.sql("UPDATE password_resets SET expires_at = now() + interval '5 seconds' WHERE user_id = :id")
                .param("id", haru.id()).update();
        confirm(haru.email(), next, "NewPassw0rd!").andExpect(status().isOk());
    }

    @Test
    @DisplayName("IT-PR-05 送り直し：1分以内はメールを送らない。1分を過ぎたら送り、前のコードは使えなくなる")
    void 送り直し() throws Exception {
        request(haru.email()).andExpect(status().isAccepted());
        String first = mailer.lastCodeTo(haru.email());
        request(haru.email()).andExpect(status().isAccepted());
        assertThat(mailer.countTo(haru.email())).isEqualTo(1);

        allowResend(haru);
        request(haru.email()).andExpect(status().isAccepted());
        assertThat(mailer.countTo(haru.email())).isEqualTo(2);
        String second = mailer.lastCodeTo(haru.email());
        if (!first.equals(second)) {
            confirm(haru.email(), first, "NewPassw0rd!").andExpect(status().isBadRequest());
        }
        confirm(haru.email(), second, "NewPassw0rd!").andExpect(status().isOk());
    }

    @Test
    @DisplayName("IT-PR-06 入力の検証：コードが6桁の数字でない・新しいパスワードが7文字・全角・メールアドレスが空は 400")
    void 入力の検証() throws Exception {
        request(haru.email()).andExpect(status().isAccepted());
        String code = mailer.lastCodeTo(haru.email());
        confirm(haru.email(), "12345", "NewPassw0rd!").andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
        confirm(haru.email(), "12345a", "NewPassw0rd!").andExpect(status().isBadRequest());
        confirm(haru.email(), code, "Short1!").andExpect(status().isBadRequest());
        confirm(haru.email(), code, "パスワードです１２").andExpect(status().isBadRequest());
        request("").andExpect(status().isBadRequest());
        // 入力の誤りは間違いの回数に数えず、正しく送れば変えられる（8文字は可：境界値）
        confirm(haru.email(), code, "Passw0rd").andExpect(status().isOk());
    }

    @Test
    @DisplayName("IT-PR-07 メールを送れなくても 202（登録の有無を知られない）。ログにメールアドレスとコードを出さない")
    void 送れないときとログ(CapturedOutput output) throws Exception {
        mailer.fail = true;
        request(haru.email()).andExpect(status().isAccepted());
        assertThat(output.getOut()).contains("mail_failed").doesNotContain(haru.email());

        mailer.fail = false;
        allowResend(haru);
        request(haru.email()).andExpect(status().isAccepted());
        String code = mailer.lastCodeTo(haru.email());
        confirm(haru.email(), code, "NewPassw0rd!").andExpect(status().isOk());
        assertThat(output.getOut()).doesNotContain(haru.email()).doesNotContain("\"" + code + "\"")
                .contains("password_reset");
    }
}
