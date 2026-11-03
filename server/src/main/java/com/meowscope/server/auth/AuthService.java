package com.meowscope.server.auth;

import com.meowscope.server.auth.AuthDtos.AuthResponse;
import com.meowscope.server.auth.AuthDtos.LoginRequest;
import com.meowscope.server.auth.AuthDtos.RegisterRequest;
import com.meowscope.server.common.error.ApiException;
import com.meowscope.server.common.error.ErrorCode;
import com.meowscope.server.common.logging.Severity;
import com.meowscope.server.user.UserRepository;
import com.meowscope.server.user.UserRepository.UserRow;
import com.meowscope.server.user.UserResponse;
import java.util.Locale;
import java.util.Optional;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 新規登録・ログイン・トークンの更新・ログアウト（API 設計書 2章、F-AU-01）。
 *
 * <p>ログには、メールアドレスとパスワードを出さず、利用者の ID だけを出す（ログ設計書 6章）。
 */
@Service
public class AuthService {

    private static final Logger log = LoggerFactory.getLogger(AuthService.class);

    private final UserRepository users;
    private final TokenService tokens;
    private final PasswordEncoder passwordEncoder;
    private final LoginAttemptLimiter limiter;
    // 存在しないメールアドレスでも同じだけ時間をかけ、応答の速さで登録の有無を知られないようにする
    private final String dummyHash;

    AuthService(UserRepository users, TokenService tokens, PasswordEncoder passwordEncoder,
            LoginAttemptLimiter limiter) {
        this.users = users;
        this.tokens = tokens;
        this.passwordEncoder = passwordEncoder;
        this.limiter = limiter;
        this.dummyHash = passwordEncoder.encode(UUID.randomUUID().toString());
    }

    @Transactional
    public AuthResponse register(RegisterRequest request) {
        String email = request.email().toLowerCase(Locale.ROOT);
        if (users.existsByEmail(email)) {
            throw new ApiException(ErrorCode.CONFLICT);
        }
        UUID id = UUID.randomUUID();
        String name = request.displayName().strip();
        try {
            users.insert(id, email, passwordEncoder.encode(request.password()), name);
        } catch (DuplicateKeyException e) {
            // 同じメールアドレスで同時に登録されたとき。DB の一意の制約で止まる
            throw new ApiException(ErrorCode.CONFLICT);
        }
        log.atInfo().addKeyValue("evt.name", "signup").addKeyValue("evt.outcome", "success")
                .addKeyValue("usr.id", id.toString()).log("新規登録");
        return response(new UserResponse(id, email, name), tokens.issue(id));
    }

    @Transactional
    public AuthResponse login(LoginRequest request) {
        String email = request.email();
        if (limiter.isLocked(email)) {
            log.atInfo().addMarker(Severity.NOTICE).addKeyValue("evt.name", "authentication")
                    .addKeyValue("evt.outcome", "failure").addKeyValue("evt.reason", "locked")
                    .log("ログインの失敗が続いたため受け付けなかった");
            throw new ApiException(ErrorCode.TOO_MANY_REQUESTS);
        }
        Optional<UserRow> user = users.findByEmail(email);
        boolean matched = passwordEncoder.matches(request.password(),
                user.map(UserRow::passwordHash).orElse(dummyHash));
        if (user.isEmpty() || !matched) {
            limiter.recordFailure(email);
            var event = log.atInfo().addMarker(Severity.NOTICE).addKeyValue("evt.name", "authentication")
                    .addKeyValue("evt.outcome", "failure").addKeyValue("evt.reason", "bad_credentials");
            user.ifPresent(u -> event.addKeyValue("usr.id", u.id().toString()));
            event.log("ログインの失敗");
            // メールアドレスの誤りかパスワードの誤りかは教えない
            throw new ApiException(ErrorCode.UNAUTHORIZED);
        }
        limiter.reset(email);
        UserRow row = user.get();
        log.atInfo().addKeyValue("evt.name", "authentication").addKeyValue("evt.outcome", "success")
                .addKeyValue("usr.id", row.id().toString()).log("ログイン");
        return response(UserResponse.of(row), tokens.issue(row.id()));
    }

    @Transactional(noRollbackFor = ApiException.class)
    public AuthResponse refresh(String refreshToken) {
        TokenService.Refreshed refreshed = tokens.refresh(refreshToken);
        UserRow row = users.findById(refreshed.userId()).orElseThrow(() -> new ApiException(ErrorCode.UNAUTHORIZED));
        return response(UserResponse.of(row), refreshed.tokens());
    }

    public void logout(UUID userId, String refreshToken) {
        tokens.revoke(refreshToken);
        log.atInfo().addKeyValue("evt.name", "logout").addKeyValue("evt.outcome", "success")
                .addKeyValue("usr.id", userId.toString()).log("ログアウト");
    }

    private static AuthResponse response(UserResponse user, TokenService.Tokens issued) {
        return new AuthResponse(issued.accessToken(), issued.refreshToken(), issued.expiresIn(), user);
    }
}
