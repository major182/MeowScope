package com.meowscope.server.auth;

import java.util.UUID;
import org.springframework.security.oauth2.jwt.Jwt;

/** アクセストークンから利用者の ID を取り出す。端末の申告ではなく、署名を確かめたトークンの中身だけを信じる。 */
public final class CurrentUser {

    private CurrentUser() {
    }

    public static UUID id(Jwt jwt) {
        return UUID.fromString(jwt.getSubject());
    }
}
