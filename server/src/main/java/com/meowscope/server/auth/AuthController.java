package com.meowscope.server.auth;

import com.meowscope.server.auth.AuthDtos.AuthResponse;
import com.meowscope.server.auth.AuthDtos.LoginRequest;
import com.meowscope.server.auth.AuthDtos.RefreshRequest;
import com.meowscope.server.auth.AuthDtos.RegisterRequest;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** 認証の API（API 設計書 2章）。業務のルールは {@link AuthService} に置き、ここでは受け渡しだけを行う。 */
@RestController
@RequestMapping("/api/v1/auth")
class AuthController {

    private final AuthService auth;

    AuthController(AuthService auth) {
        this.auth = auth;
    }

    @PostMapping("/register")
    @ResponseStatus(HttpStatus.CREATED)
    AuthResponse register(@Valid @RequestBody RegisterRequest request) {
        return auth.register(request);
    }

    @PostMapping("/login")
    AuthResponse login(@Valid @RequestBody LoginRequest request) {
        return auth.login(request);
    }

    @PostMapping("/refresh")
    AuthResponse refresh(@Valid @RequestBody RefreshRequest request) {
        return auth.refresh(request.refreshToken());
    }

    @PostMapping("/logout")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    void logout(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody RefreshRequest request) {
        auth.logout(CurrentUser.id(jwt), request.refreshToken());
    }
}
