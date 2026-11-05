package com.meowscope.server.mail;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.DefaultValue;

/**
 * メールの送り方（技術選定書 2章、Q-26）。SMTP で送り、どのサービス（Gmail・Brevo・Resend など）でも設定だけで切り替える。
 *
 * <p>パスワードは秘密の置き場に置き、環境変数で渡す。{@code host} が空なら送らない（{@link NotConfiguredMailer}）。
 *
 * @param host SMTP のサーバー（例：smtp.gmail.com）
 * @param port SMTP のポート（STARTTLS の 587）
 * @param username SMTP のユーザー
 * @param password SMTP のパスワード（Gmail ならアプリパスワード）
 * @param from 送り元のメールアドレス
 * @param starttls STARTTLS で暗号化するか
 */
@ConfigurationProperties("meowscope.mail")
public record MailProperties(
        @DefaultValue("") String host,
        @DefaultValue("587") int port,
        @DefaultValue("") String username,
        @DefaultValue("") String password,
        @DefaultValue("") String from,
        @DefaultValue("true") boolean starttls) {

    /** 送る準備ができているか。 */
    boolean configured() {
        return !host.isBlank() && !from.isBlank();
    }
}
