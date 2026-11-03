package com.meowscope.server.user;

import java.util.UUID;

/** 自分の情報（API 設計書 3章 GET /me）。パスワードのハッシュは含めない。 */
public record UserResponse(UUID id, String email, String displayName) {

    public static UserResponse of(UserRepository.UserRow row) {
        return new UserResponse(row.id(), row.email(), row.displayName());
    }
}
