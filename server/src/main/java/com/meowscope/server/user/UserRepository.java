package com.meowscope.server.user;

import java.util.Optional;
import java.util.UUID;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

/** ユーザーの表（DB 設計書 4章 users・user_settings）。 */
@Repository
public class UserRepository {

    private final JdbcClient jdbc;

    public UserRepository(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    /** ユーザーの1行。パスワードのハッシュはサーバーの外へ出さない。 */
    public record UserRow(UUID id, String email, String passwordHash, String displayName, String iconPath) {
    }

    /** ユーザーと、既定の値の設定を登録する。メールアドレスは呼ぶ側で小文字にそろえる。 */
    public void insert(UUID id, String email, String passwordHash, String displayName) {
        jdbc.sql("INSERT INTO users (id, email, password_hash, display_name) VALUES (:id, :email, :hash, :name)")
                .param("id", id).param("email", email).param("hash", passwordHash).param("name", displayName)
                .update();
        jdbc.sql("INSERT INTO user_settings (id, user_id) VALUES (:id, :userId)")
                .param("id", UUID.randomUUID()).param("userId", id)
                .update();
    }

    public boolean existsByEmail(String email) {
        return jdbc.sql("SELECT count(*) FROM users WHERE lower(email) = lower(:email)")
                .param("email", email).query(Long.class).single() > 0;
    }

    public Optional<UserRow> findByEmail(String email) {
        return jdbc.sql("""
                SELECT id, email, password_hash, display_name, icon_path FROM users
                WHERE lower(email) = lower(:email)
                """).param("email", email).query(UserRow.class).optional();
    }

    public Optional<UserRow> findById(UUID id) {
        return jdbc.sql("SELECT id, email, password_hash, display_name, icon_path FROM users WHERE id = :id")
                .param("id", id).query(UserRow.class).optional();
    }

    /** 表示名を変える。同期で相手の端末へ届くよう、通し番号を振り直す（BR-10）。 */
    public void updateDisplayName(UUID id, String displayName) {
        jdbc.sql("""
                UPDATE users SET display_name = :name, updated_at = now(), server_seq = nextval('sync_seq')
                WHERE id = :id
                """).param("id", id).param("name", displayName).update();
    }
}
