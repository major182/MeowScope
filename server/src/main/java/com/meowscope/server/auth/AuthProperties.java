package com.meowscope.server.auth;

import java.time.Duration;
import java.util.Base64;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.DefaultValue;

/**
 * 認証の設定（API 設計書 2章、NF-SC-03）。値は application.properties と環境変数から受け取る。
 *
 * @param jwtSecret アクセストークンの署名鍵（Base64）。秘密の置き場から環境変数 {@code JWT_SECRET} で渡す
 * @param accessTokenTtl アクセストークンの有効期間（15分）
 * @param refreshTokenTtl 更新トークンの有効期間（30日）
 * @param loginMaxFailures ログインを止めるまでに許す失敗の回数
 * @param loginLockDuration 失敗を数える期間で、止める時間でもある
 */
@ConfigurationProperties("meowscope.auth")
public record AuthProperties(
        String jwtSecret,
        @DefaultValue("15m") Duration accessTokenTtl,
        @DefaultValue("30d") Duration refreshTokenTtl,
        @DefaultValue("5") int loginMaxFailures,
        @DefaultValue("15m") Duration loginLockDuration) {

    /** HS256 の鍵は 256 ビット（32 バイト）以上が必要（RFC 7518）。短い鍵は総当たりで破られるので起動させない。 */
    static final int MIN_SECRET_BYTES = 32;

    public AuthProperties {
        if (jwtSecret == null || jwtSecret.isBlank()) {
            throw new IllegalStateException("JWT_SECRET を設定してください");
        }
        byte[] key;
        try {
            key = Base64.getDecoder().decode(jwtSecret);
        } catch (IllegalArgumentException e) {
            throw new IllegalStateException("JWT_SECRET は Base64 で書いてください", e);
        }
        if (key.length < MIN_SECRET_BYTES) {
            throw new IllegalStateException("JWT_SECRET は 32 バイト以上にしてください");
        }
    }

    byte[] jwtSecretBytes() {
        return Base64.getDecoder().decode(jwtSecret);
    }
}
