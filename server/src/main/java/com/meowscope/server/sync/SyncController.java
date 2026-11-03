package com.meowscope.server.sync;

import com.meowscope.server.auth.CurrentUser;
import com.meowscope.server.sync.SyncDtos.SyncRequest;
import com.meowscope.server.sync.SyncDtos.SyncResponse;
import jakarta.validation.Valid;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

/** 同期の API（API 設計書 5章）。 */
@RestController
class SyncController {

    private final SyncService sync;

    SyncController(SyncService sync) {
        this.sync = sync;
    }

    @PostMapping("/api/v1/sync")
    SyncResponse sync(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody SyncRequest request) {
        return sync.sync(CurrentUser.id(jwt), request);
    }
}
