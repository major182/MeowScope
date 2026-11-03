package com.meowscope.server.user;

import com.meowscope.server.auth.CurrentUser;
import com.meowscope.server.auth.TokenService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** 自分の情報（API 設計書 3章）。アイコンは No.14 で足す。業務のルールは {@link AccountService} に置く。 */
@RestController
@RequestMapping("/api/v1/me")
class MeController {

    private final AccountService account;

    MeController(AccountService account) {
        this.account = account;
    }

    record UpdateRequest(@NotBlank @Size(max = 20) String displayName) {
    }

    /** 新しいパスワードは新規登録と同じ決まり（半角、8〜64文字。BR-26）。 */
    record PasswordRequest(
            @NotBlank @Size(max = 64) String currentPassword,
            @NotNull @Size(min = 8, max = 64) @Pattern(regexp = "^[\\x21-\\x7E]+$") String newPassword) {
    }

    record DeleteRequest(@NotNull Boolean keepRecords) {
    }

    @GetMapping
    UserResponse get(@AuthenticationPrincipal Jwt jwt) {
        return account.get(CurrentUser.id(jwt));
    }

    @PatchMapping
    UserResponse update(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody UpdateRequest request) {
        return account.rename(CurrentUser.id(jwt), request.displayName());
    }

    @PutMapping("/password")
    TokenService.Tokens changePassword(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody PasswordRequest request) {
        return account.changePassword(CurrentUser.id(jwt), request.currentPassword(), request.newPassword());
    }

    @DeleteMapping
    @ResponseStatus(HttpStatus.NO_CONTENT)
    void delete(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody DeleteRequest request) {
        account.delete(CurrentUser.id(jwt), request.keepRecords());
    }
}
