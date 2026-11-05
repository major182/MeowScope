package com.meowscope.server.mail;

import java.time.Duration;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;

/** SMTP で確認コードを送る。 */
class SmtpPasswordResetMailer implements PasswordResetMailer {

    static final String SUBJECT = "【MeowScope】パスワードの再設定の確認コード";

    private final JavaMailSender sender;
    private final String from;

    SmtpPasswordResetMailer(JavaMailSender sender, String from) {
        this.sender = sender;
        this.from = from;
    }

    @Override
    public void sendCode(String to, String code, Duration validFor) {
        SimpleMailMessage message = new SimpleMailMessage();
        message.setFrom(from);
        message.setTo(to);
        message.setSubject(SUBJECT);
        message.setText(body(code, validFor));
        try {
            sender.send(message);
        } catch (org.springframework.mail.MailException e) {
            // 完全な名前で書く。単に MailException と書くと、実装しているインターフェースの中の同じ名前の型になる
            throw new PasswordResetMailer.MailException("確認コードのメールを送れなかった", e);
        }
    }

    static String body(String code, Duration validFor) {
        return """
                MeowScope のパスワードの再設定を受け付けました。
                アプリの「パスワード再設定」の画面に、次の確認コードを入れてください。

                確認コード：%s

                このコードは%d分のあいだ有効です。
                心当たりがないときは、このメールを捨ててください。パスワードは変わりません。
                """.formatted(code, validFor.toMinutes());
    }
}
