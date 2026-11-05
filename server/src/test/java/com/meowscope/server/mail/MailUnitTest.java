package com.meowscope.server.mail;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;

import java.time.Duration;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.springframework.boot.test.system.CapturedOutput;
import org.springframework.boot.test.system.OutputCaptureExtension;
import org.springframework.mail.MailSendException;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.JavaMailSenderImpl;

@ExtendWith(OutputCaptureExtension.class)
class MailUnitTest {

    private static MailProperties props(String host, String user, String from, boolean starttls) {
        return new MailProperties(host, 587, user, "secret", from, starttls);
    }

    @Test
    @DisplayName("UT-PR-01 送り方の選択：SMTP のサーバーか送り元が空なら送らない方、両方あれば SMTP（デシジョンテーブル）")
    void 送り方の選択() {
        MailConfig config = new MailConfig();
        assertThat(config.passwordResetMailer(props("", "", "", true))).isInstanceOf(NotConfiguredMailer.class);
        assertThat(config.passwordResetMailer(props("smtp.example.com", "", "", true)))
                .isInstanceOf(NotConfiguredMailer.class);
        assertThat(config.passwordResetMailer(props("", "", "no-reply@example.com", true)))
                .isInstanceOf(NotConfiguredMailer.class);
        assertThat(config.passwordResetMailer(props("smtp.example.com", "", "no-reply@example.com", true)))
                .isInstanceOf(SmtpPasswordResetMailer.class);
    }

    @Test
    @DisplayName("UT-PR-02 SMTP の接続：ユーザーがあれば認証し、STARTTLS を必須にし、待つ時間に上限を設ける。ユーザーが空なら認証しない")
    void SMTPの接続() {
        JavaMailSenderImpl sender = MailConfig.sender(props("smtp.example.com", "me@example.com", "x@example.com",
                true));
        assertThat(sender.getHost()).isEqualTo("smtp.example.com");
        assertThat(sender.getPort()).isEqualTo(587);
        assertThat(sender.getUsername()).isEqualTo("me@example.com");
        assertThat(sender.getJavaMailProperties()).containsEntry("mail.smtp.auth", "true")
                .containsEntry("mail.smtp.starttls.enable", "true").containsEntry("mail.smtp.starttls.required", "true")
                .containsEntry("mail.smtp.timeout", MailConfig.TIMEOUT_MS);

        JavaMailSenderImpl plain = MailConfig.sender(new MailProperties("localhost", 25, "", "", "x@example.com", false));
        assertThat(plain.getUsername()).isNull();
        assertThat(plain.getPassword()).isNull();
        assertThat(plain.getJavaMailProperties()).containsEntry("mail.smtp.auth", "false")
                .containsEntry("mail.smtp.starttls.enable", "false");
    }

    @Test
    @DisplayName("UT-PR-03 送るメール：送り元・宛先・件名と、コードと有効の分数を入れた本文")
    void 送るメール() {
        JavaMailSender sender = mock(JavaMailSender.class);
        new SmtpPasswordResetMailer(sender, "no-reply@example.com").sendCode("haru@example.com", "012345",
                Duration.ofMinutes(15));

        ArgumentCaptor<SimpleMailMessage> sent = ArgumentCaptor.forClass(SimpleMailMessage.class);
        verify(sender).send(sent.capture());
        SimpleMailMessage message = sent.getValue();
        assertThat(message.getFrom()).isEqualTo("no-reply@example.com");
        assertThat(message.getTo()).containsExactly("haru@example.com");
        assertThat(message.getSubject()).isEqualTo(SmtpPasswordResetMailer.SUBJECT);
        assertThat(message.getText()).contains("確認コード：012345").contains("15分");
    }

    @Test
    @DisplayName("UT-PR-04 異常系：SMTP で送れなければ、送れなかった例外に変える")
    void 送れない() {
        JavaMailSender sender = mock(JavaMailSender.class);
        doThrow(new MailSendException("down")).when(sender).send(any(SimpleMailMessage.class));
        assertThatThrownBy(() -> new SmtpPasswordResetMailer(sender, "x@example.com").sendCode("a@example.com",
                "123456", Duration.ofMinutes(15))).isInstanceOf(PasswordResetMailer.MailException.class);
    }

    @Test
    @DisplayName("UT-PR-05 設定がないときは送らずに warning を残す。宛先とコードはログに出さない")
    void 設定がない(CapturedOutput output) {
        new NotConfiguredMailer().sendCode("haru@example.com", "987654", Duration.ofMinutes(15));
        assertThat(output.getOut()).contains("not_configured").doesNotContain("haru@example.com")
                .doesNotContain("987654");
    }
}
