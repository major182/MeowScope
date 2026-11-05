package com.meowscope.server.auth;

import com.meowscope.server.auth.AuthDtos.AuthResponse;
import com.meowscope.server.common.error.ApiException;
import com.meowscope.server.common.error.ErrorCode;
import com.meowscope.server.common.logging.Severity;
import com.meowscope.server.mail.PasswordResetMailer;
import com.meowscope.server.user.UserRepository;
import com.meowscope.server.user.UserRepository.UserRow;
import com.meowscope.server.user.UserResponse;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.HexFormat;
import java.util.Optional;
import java.util.UUID;
import java.util.random.RandomGenerator;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * パスワードの再設定（API 設計書 2章、F-AU-03）。メールに6桁の確認コードを送り、コードと新しいパスワードで変える。
 *
 * <ul>
 *   <li>受付は、メールアドレスが登録されていなくても同じ応答にする（登録の有無を知られないため）
 *   <li>コードはハッシュだけを DB に置く。15分で期限が切れ、5回間違えたら使えなくなる。送り直すと前のコードは使えなくなる
 *   <li>送り直しは1分あける（メールを大量に送らせないため）
 *   <li>変えたら、ほかの端末のログインはすべて無効にし、この端末にトークンを渡す（パスワードの変更と同じ）
 *   <li>ログには、メールアドレスとコードを出さない（ログ設計書 6章）
 * </ul>
 */
@Service
public class PasswordResetService {

    private static final Logger log = LoggerFactory.getLogger(PasswordResetService.class);

    static final Duration CODE_TTL = Duration.ofMinutes(15);
    static final int MAX_ATTEMPTS = 5;
    static final Duration RESEND_INTERVAL = Duration.ofMinutes(1);

    private final UserRepository users;
    private final JdbcClient jdbc;
    private final PasswordEncoder passwordEncoder;
    private final TokenService tokens;
    private final PasswordResetMailer mailer;
    private final Clock clock;
    private final RandomGenerator random = new SecureRandom();

    PasswordResetService(UserRepository users, JdbcClient jdbc, PasswordEncoder passwordEncoder, TokenService tokens,
            PasswordResetMailer mailer, Clock clock) {
        this.users = users;
        this.jdbc = jdbc;
        this.passwordEncoder = passwordEncoder;
        this.tokens = tokens;
        this.mailer = mailer;
        this.clock = clock;
    }

    /** 確認コードを作って送る。登録されていない・送り直しが早すぎるときは、何もせずに終える。 */
    @Transactional
    public void request(String email) {
        Optional<UserRow> user = users.findByEmail(email);
        if (user.isEmpty()) {
            log.atInfo().addMarker(Severity.NOTICE).addKeyValue("evt.name", "password_reset_request")
                    .addKeyValue("evt.outcome", "failure").addKeyValue("evt.reason", "unknown_email")
                    .log("登録されていないメールアドレスへの再設定の受付");
            return;
        }
        UUID id = user.get().id();
        Instant now = clock.instant();
        Optional<Instant> last = jdbc.sql("SELECT created_at FROM password_resets WHERE user_id = :id")
                .param("id", id).query(Timestamp.class).optional().map(Timestamp::toInstant);
        if (last.isPresent() && now.isBefore(last.get().plus(RESEND_INTERVAL))) {
            log.atInfo().addKeyValue("evt.name", "password_reset_request").addKeyValue("evt.outcome", "failure")
                    .addKeyValue("evt.reason", "too_soon").addKeyValue("usr.id", id.toString())
                    .log("再設定の受付が早すぎるため送らなかった");
            return;
        }
        String code = newCode(random);
        jdbc.sql("""
                INSERT INTO password_resets (user_id, code_hash, expires_at, attempts, created_at)
                VALUES (:id, :hash, :expires, 0, :now)
                ON CONFLICT (user_id) DO UPDATE SET code_hash = :hash, expires_at = :expires, attempts = 0,
                  created_at = :now
                """).param("id", id).param("hash", hash(id, code))
                .param("expires", Timestamp.from(now.plus(CODE_TTL))).param("now", Timestamp.from(now)).update();
        try {
            mailer.sendCode(user.get().email(), code, CODE_TTL);
        } catch (PasswordResetMailer.MailException e) {
            // 送れなかったことは応答では教えない（登録の有無が分かってしまうため）。送り直しで直せる
            log.atError().addKeyValue("evt.name", "password_reset_request").addKeyValue("evt.outcome", "failure")
                    .addKeyValue("evt.reason", "mail_failed").addKeyValue("usr.id", id.toString())
                    .log("確認コードのメールを送れなかった", e);
            return;
        }
        log.atInfo().addKeyValue("evt.name", "password_reset_request").addKeyValue("evt.outcome", "success")
                .addKeyValue("usr.id", id.toString()).log("確認コードを送った");
    }

    /**
     * コードを確かめて、パスワードを変える。
     *
     * @throws ApiException コードが違う・期限切れ・使えなくなった・受付がないときは、どれも 400（INVALID_RESET_CODE）
     */
    @Transactional(noRollbackFor = ApiException.class)
    public AuthResponse confirm(String email, String code, String newPassword) {
        UserRow user = users.findByEmail(email).orElseThrow(PasswordResetService::invalid);
        UUID id = user.id();
        record Reset(String codeHash, Instant expiresAt, int attempts) {
        }
        Reset reset = jdbc.sql("SELECT code_hash, expires_at, attempts FROM password_resets WHERE user_id = :id")
                .param("id", id)
                .query((rs, n) -> new Reset(rs.getString("code_hash"), rs.getTimestamp("expires_at").toInstant(),
                        rs.getInt("attempts")))
                .optional().orElseThrow(PasswordResetService::invalid);
        if (!clock.instant().isBefore(reset.expiresAt()) || reset.attempts() >= MAX_ATTEMPTS) {
            delete(id);
            throw failed(id, "expired");
        }
        if (!MessageDigest.isEqual(reset.codeHash().getBytes(StandardCharsets.US_ASCII),
                hash(id, code).getBytes(StandardCharsets.US_ASCII))) {
            if (reset.attempts() + 1 >= MAX_ATTEMPTS) {
                delete(id);
            } else {
                jdbc.sql("UPDATE password_resets SET attempts = attempts + 1 WHERE user_id = :id").param("id", id)
                        .update();
            }
            throw failed(id, "wrong_code");
        }
        jdbc.sql("UPDATE users SET password_hash = :hash WHERE id = :id")
                .param("id", id).param("hash", passwordEncoder.encode(newPassword)).update();
        jdbc.sql("UPDATE refresh_tokens SET revoked_at = now() WHERE user_id = :id AND revoked_at IS NULL")
                .param("id", id).update();
        delete(id);
        log.atInfo().addMarker(Severity.NOTICE).addKeyValue("evt.name", "password_reset")
                .addKeyValue("evt.outcome", "success").addKeyValue("usr.id", id.toString()).log("パスワードの再設定");
        TokenService.Tokens issued = tokens.issue(id);
        return new AuthResponse(issued.accessToken(), issued.refreshToken(), issued.expiresIn(),
                UserResponse.of(user));
    }

    private void delete(UUID id) {
        jdbc.sql("DELETE FROM password_resets WHERE user_id = :id").param("id", id).update();
    }

    private static ApiException invalid() {
        return new ApiException(ErrorCode.INVALID_RESET_CODE);
    }

    private static ApiException failed(UUID id, String reason) {
        log.atInfo().addMarker(Severity.NOTICE).addKeyValue("evt.name", "password_reset")
                .addKeyValue("evt.outcome", "failure").addKeyValue("evt.reason", reason)
                .addKeyValue("usr.id", id.toString()).log("パスワードの再設定の失敗");
        return invalid();
    }

    /** 6桁の確認コード（先頭の 0 も含める）。 */
    static String newCode(RandomGenerator random) {
        return "%06d".formatted(random.nextInt(1_000_000));
    }

    /** コードのハッシュ。ユーザーの ID を混ぜ、同じコードでも人ごとに違う値にする。 */
    static String hash(UUID userId, String code) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256")
                    .digest((userId + ":" + code).getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(digest);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }
}
