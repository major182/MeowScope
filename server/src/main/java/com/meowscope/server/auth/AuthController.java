package com.meowscope.server.auth;

import com.meowscope.server.auth.AuthDtos.AuthResponse;
import com.meowscope.server.auth.AuthDtos.LoginRequest;
import com.meowscope.server.auth.AuthDtos.PasswordResetConfirm;
import com.meowscope.server.auth.AuthDtos.PasswordResetRequest;
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
    private final PasswordResetService passwordReset;

    AuthController(AuthService auth, PasswordResetService passwordReset) {
        this.auth = auth;
        this.passwordReset = passwordReset;
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

    /** 確認コードを送る。登録の有無にかかわらず 202 を返す。 */
    @PostMapping("/password-reset/request")
    @ResponseStatus(HttpStatus.ACCEPTED)
    void requestPasswordReset(@Valid @RequestBody PasswordResetRequest request) {
        passwordReset.request(request.email());
    }

    /** コードを確かめてパスワードを変え、ログインした状態の応答を返す。 */
    @PostMapping("/password-reset/confirm")
    AuthResponse confirmPasswordReset(@Valid @RequestBody PasswordResetConfirm request) {
        return passwordReset.confirm(request.email(), request.code(), request.newPassword());
    }

    @PostMapping("/logout")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    void logout(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody RefreshRequest request) {
        auth.logout(CurrentUser.id(jwt), request.refreshToken());
    }
}
