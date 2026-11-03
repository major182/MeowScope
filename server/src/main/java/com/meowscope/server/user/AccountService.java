package com.meowscope.server.user;

import com.meowscope.server.auth.TokenService;
import com.meowscope.server.common.error.ApiException;
import com.meowscope.server.common.error.ErrorCode;
import com.meowscope.server.common.logging.Severity;
import com.meowscope.server.household.LeaveService;
import com.meowscope.server.photo.PhotoStorage;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** アカウントの変更（API 設計書 3章）。表示名・パスワードの変更と退会。 */
@Service
public class AccountService {

    private static final Logger log = LoggerFactory.getLogger(AccountService.class);

    private final UserRepository users;
    private final PasswordEncoder passwordEncoder;
    private final TokenService tokens;
    private final LeaveService leave;
    private final JdbcClient jdbc;
    private final PhotoStorage storage;

    AccountService(UserRepository users, PasswordEncoder passwordEncoder, TokenService tokens, LeaveService leave,
            JdbcClient jdbc, PhotoStorage storage) {
        this.storage = storage;
        this.users = users;
        this.passwordEncoder = passwordEncoder;
        this.tokens = tokens;
        this.leave = leave;
        this.jdbc = jdbc;
    }

    private UserRepository.UserRow find(UUID id) {
        // 退会の後に残っていたトークンで呼ばれたときは、ログインし直してもらう
        return users.findById(id).orElseThrow(() -> new ApiException(ErrorCode.UNAUTHORIZED));
    }

    public UserResponse get(UUID id) {
        return UserResponse.of(find(id));
    }

    @Transactional
    public UserResponse rename(UUID id, String displayName) {
        find(id);
        users.updateDisplayName(id, displayName.strip());
        return UserResponse.of(find(id));
    }

    /**
     * パスワードを変える。今のパスワードを確かめ、ほかの端末のログインはすべて無効にして、この端末に新しいトークンを渡す。
     *
     * @throws ApiException 今のパスワードが違えば 403
     */
    @Transactional
    public TokenService.Tokens changePassword(UUID id, String current, String next) {
        UserRepository.UserRow user = find(id);
        if (!passwordEncoder.matches(current, user.passwordHash())) {
            throw new ApiException(ErrorCode.FORBIDDEN);
        }
        jdbc.sql("UPDATE users SET password_hash = :hash WHERE id = :id")
                .param("id", id).param("hash", passwordEncoder.encode(next)).update();
        jdbc.sql("UPDATE refresh_tokens SET revoked_at = now() WHERE user_id = :id AND revoked_at IS NULL")
                .param("id", id).update();
        log.atInfo().addMarker(Severity.NOTICE).addKeyValue("evt.name", "password_change")
                .addKeyValue("evt.outcome", "success").addKeyValue("usr.id", id.toString()).log("パスワードの変更");
        return tokens.issue(id);
    }

    /**
     * 退会する（BR-15、BR-16、DB 設計書 7章）。属するおうちをすべて抜けてから、ユーザーを物理削除する。
     * 残す記録は、投稿者の ID が空になり（外部キーの ON DELETE SET NULL）、投稿者名は残る（BR-17）。
     */
    @Transactional
    public void delete(UUID id, boolean keepRecords) {
        find(id);
        for (UUID household : leave.householdsOf(id)) {
            leave.leave(id, household, keepRecords);
        }
        String icon = users.findById(id).map(UserRepository.UserRow::iconPath).orElse(null);
        jdbc.sql("DELETE FROM users WHERE id = :id").param("id", id).update();
        storage.delete(icon);
        log.atInfo().addMarker(Severity.NOTICE).addKeyValue("evt.name", "account_delete")
                .addKeyValue("evt.outcome", "success").addKeyValue("usr.id", id.toString())
                .addKeyValue("evt.reason", keepRecords ? "keep" : "delete").log("退会");
    }
}
