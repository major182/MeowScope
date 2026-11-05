package com.meowscope.server.mail;

import java.util.Properties;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.mail.javamail.JavaMailSenderImpl;

/** メールの送り方を選ぶ。設定がなければ送らない。 */
@Configuration
@EnableConfigurationProperties(MailProperties.class)
class MailConfig {

    /** SMTP の接続と応答を待つ上限。届かないサーバーで要求を長く止めない。 */
    static final String TIMEOUT_MS = "10000";

    @Bean
    PasswordResetMailer passwordResetMailer(MailProperties properties) {
        if (!properties.configured()) {
            return new NotConfiguredMailer();
        }
        return new SmtpPasswordResetMailer(sender(properties), properties.from());
    }

    static JavaMailSenderImpl sender(MailProperties properties) {
        JavaMailSenderImpl sender = new JavaMailSenderImpl();
        sender.setHost(properties.host());
        sender.setPort(properties.port());
        sender.setUsername(properties.username().isBlank() ? null : properties.username());
        sender.setPassword(properties.password().isBlank() ? null : properties.password());
        sender.setDefaultEncoding("UTF-8");
        Properties props = sender.getJavaMailProperties();
        props.put("mail.smtp.auth", String.valueOf(!properties.username().isBlank()));
        props.put("mail.smtp.starttls.enable", String.valueOf(properties.starttls()));
        props.put("mail.smtp.starttls.required", String.valueOf(properties.starttls()));
        props.put("mail.smtp.connectiontimeout", TIMEOUT_MS);
        props.put("mail.smtp.timeout", TIMEOUT_MS);
        props.put("mail.smtp.writetimeout", TIMEOUT_MS);
        return sender;
    }
}
