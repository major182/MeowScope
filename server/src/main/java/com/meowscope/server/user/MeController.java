package com.meowscope.server.user;

import com.meowscope.server.auth.CurrentUser;
import com.meowscope.server.common.error.ApiException;
import com.meowscope.server.common.error.ErrorCode;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.UUID;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** 自分の情報（API 設計書 3章）。パスワードの変更・アイコン・退会は、アカウントの実装（No.12・14）で足す。 */
@RestController
@RequestMapping("/api/v1/me")
class MeController {

    private final UserRepository users;

    MeController(UserRepository users) {
        this.users = users;
    }

    record UpdateRequest(@NotBlank @Size(max = 20) String displayName) {
    }

    @GetMapping
    UserResponse get(@AuthenticationPrincipal Jwt jwt) {
        return UserResponse.of(find(CurrentUser.id(jwt)));
    }

    @PatchMapping
    @Transactional
    UserResponse update(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody UpdateRequest request) {
        UUID id = CurrentUser.id(jwt);
        find(id);
        users.updateDisplayName(id, request.displayName().strip());
        return UserResponse.of(find(id));
    }

    /** 退会の後に残っていたトークンで呼ばれたときは、見つからないとして扱う。 */
    private UserRepository.UserRow find(UUID id) {
        return users.findById(id).orElseThrow(() -> new ApiException(ErrorCode.UNAUTHORIZED));
    }
}
