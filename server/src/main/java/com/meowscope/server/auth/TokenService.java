package com.meowscope.server.auth;

import com.meowscope.server.common.error.ApiException;
import com.meowscope.server.common.error.ErrorCode;
import com.meowscope.server.common.logging.Severity;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Clock;
import java.time.Instant;
import java.util.Base64;
import java.util.HexFormat;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * アクセストークンと更新トークンを発行・交換・無効にする（API 設計書 2章、技術選定書 4章）。
 *
 * <ul>
 *   <li>アクセストークン：JWT（15分）。サーバーは署名と期限だけを確かめ、DB は見ない
 *   <li>更新トークン：ランダムな値（30日）。DB にはハッシュだけを置き、使うたびに新しいものへ交換する
 *   <li>使い終わった更新トークンがもう一度使われたら、盗まれた疑いがあるので、そのユーザーの全トークンを無効にする
 * </ul>
 */
@Service
public class TokenService {

    private static final Logger log = LoggerFactory.getLogger(TokenService.class);
    private static final SecureRandom RANDOM = new SecureRandom();
    private static final int REFRESH_TOKEN_BYTES = 32;

    private final JwtEncoder encoder;
    private final RefreshTokenRepository tokens;
    private final AuthProperties properties;
    private final Clock clock;

    TokenService(JwtEncoder encoder, RefreshTokenRepository tokens, AuthProperties properties, Clock clock) {
        this.encoder = encoder;
        this.tokens = tokens;
        this.properties = properties;
        this.clock = clock;
    }

    /** 発行したトークン。{@code expiresIn} はアクセストークンの残りの秒数。 */
    public record Tokens(String accessToken, String refreshToken, long expiresIn) {
    }

    /** ログイン・新規登録のときに、新しい組を発行する。 */
    @Transactional
    public Tokens issue(UUID userId) {
        Instant now = clock.instant();
        JwtClaimsSet claims = JwtClaimsSet.builder()
                .issuer("meowscope")
                .subject(userId.toString())
                .issuedAt(now)
                .expiresAt(now.plus(properties.accessTokenTtl()))
                .build();
        String access = encoder.encode(JwtEncoderParameters.from(JwsHeader.with(MacAlgorithm.HS256).build(), claims))
                .getTokenValue();
        byte[] random = new byte[REFRESH_TOKEN_BYTES];
        RANDOM.nextBytes(random);
        String refresh = Base64.getUrlEncoder().withoutPadding().encodeToString(random);
        tokens.insert(userId, hash(refresh), now.plus(properties.refreshTokenTtl()));
        return new Tokens(access, refresh, properties.accessTokenTtl().toSeconds());
    }

    /**
     * 更新トークンを新しい組に交換する。
     *
     * @return 新しい組と、そのユーザーの ID
     * @throws ApiException 知らない・期限切れ・使い終わったトークンのとき（401）
     */
    @Transactional(noRollbackFor = ApiException.class)
    public Refreshed refresh(String refreshToken) {
        Instant now = clock.instant();
        RefreshTokenRepository.TokenRow row = tokens.findByHash(hash(refreshToken))
                .orElseThrow(() -> new ApiException(ErrorCode.UNAUTHORIZED));
        if (row.revokedAt() != null || !tokens.revoke(row.id(), now)) {
            // 交換や取り消しの済んだトークンがまた来た。持ち主と盗んだ人の両方が使っている恐れがある（ログ設計書 5章）
            tokens.revokeAll(row.userId(), now);
            log.atError().addMarker(Severity.ALERT)
                    .addKeyValue("evt.name", "refresh_token_reuse")
                    .addKeyValue("evt.outcome", "failure")
                    .addKeyValue("usr.id", row.userId().toString())
                    .log("使い終わった更新トークンが使われたため、全トークンを無効にした");
            throw new ApiException(ErrorCode.UNAUTHORIZED);
        }
        if (!row.expiresAt().isAfter(now)) {
            throw new ApiException(ErrorCode.UNAUTHORIZED);
        }
        return new Refreshed(row.userId(), issue(row.userId()));
    }

    public record Refreshed(UUID userId, Tokens tokens) {
    }

    /** ログアウトのとき、渡された更新トークンを無効にする。知らないトークンでも失敗にしない。 */
    @Transactional
    public void revoke(String refreshToken) {
        tokens.findByHash(hash(refreshToken)).ifPresent(row -> tokens.revoke(row.id(), clock.instant()));
    }

    /** トークンのハッシュ。ランダムで十分に長い値なので、パスワードと違い、速い SHA-256 で足りる。 */
    static String hash(String token) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(token.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(digest);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }
}
