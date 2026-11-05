package com.meowscope.server.mail;

import java.time.Duration;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * メールの送り方が設定されていないとき（Q-26 が決まるまで）。送らずに warning を残す。
 * 宛先とコードはログに出さない（ログ設計書 6章）。
 */
class NotConfiguredMailer implements PasswordResetMailer {

    private static final Logger log = LoggerFactory.getLogger(NotConfiguredMailer.class);

    @Override
    public void sendCode(String to, String code, Duration validFor) {
        log.atWarn().addKeyValue("evt.name", "mail").addKeyValue("evt.outcome", "failure")
                .addKeyValue("evt.reason", "not_configured")
                .log("メールの送り方が設定されていないため、確認コードを送らなかった");
    }
}
