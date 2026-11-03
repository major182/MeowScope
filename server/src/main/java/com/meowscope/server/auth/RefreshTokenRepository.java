package com.meowscope.server.auth;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

/** 更新トークンの表（DB 設計書 5章 refresh_tokens）。トークンそのものは持たず、ハッシュだけを持つ。 */
@Repository
class RefreshTokenRepository {

    private final JdbcClient jdbc;

    RefreshTokenRepository(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    record TokenRow(UUID id, UUID userId, Instant expiresAt, Instant revokedAt) {
    }

    void insert(UUID userId, String tokenHash, Instant expiresAt) {
        jdbc.sql("INSERT INTO refresh_tokens (id, user_id, token_hash, expires_at) VALUES (:id, :userId, :hash, :exp)")
                .param("id", UUID.randomUUID()).param("userId", userId).param("hash", tokenHash)
                .param("exp", java.sql.Timestamp.from(expiresAt))
                .update();
    }

    Optional<TokenRow> findByHash(String tokenHash) {
        return jdbc.sql("SELECT id, user_id, expires_at, revoked_at FROM refresh_tokens WHERE token_hash = :hash")
                .param("hash", tokenHash).query(TokenRow.class).optional();
    }

    /**
     * まだ使われていなければ無効にする。
     *
     * @return 無効にできたら true。同時に2回使われたときは、片方だけが true になる
     */
    boolean revoke(UUID id, Instant now) {
        return jdbc.sql("UPDATE refresh_tokens SET revoked_at = :now WHERE id = :id AND revoked_at IS NULL")
                .param("id", id).param("now", java.sql.Timestamp.from(now)).update() == 1;
    }

    /** そのユーザーの有効なトークンをすべて無効にする（使い回しを検知したとき）。 */
    void revokeAll(UUID userId, Instant now) {
        jdbc.sql("UPDATE refresh_tokens SET revoked_at = :now WHERE user_id = :userId AND revoked_at IS NULL")
                .param("userId", userId).param("now", java.sql.Timestamp.from(now)).update();
    }
}
