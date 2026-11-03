package com.meowscope.server.clientlog;

import com.meowscope.server.auth.CurrentUser;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** 端末のログの受信（API 設計書 7章、ログ設計書 8章）。 */
@RestController
class ClientLogController {

    private final ClientLogService logs;

    ClientLogController(ClientLogService logs) {
        this.logs = logs;
    }

    /**
     * 端末のログ1件。値は信用せず、長さと形を確かめる。{@code status} は端末から出せる重大度だけ（alert は出させない）。
     */
    record ClientLog(
            @NotNull @Pattern(regexp = "critical|error|warning|notice|info") String status,
            @NotBlank @Size(max = ClientLogService.MAX_MESSAGE) String message,
            @Size(max = 40) String occurredAt,
            @Pattern(regexp = "windows|android") String platform,
            @Size(max = 40) String appVersion,
            @Size(max = 100) String osVersion,
            @Pattern(regexp = "[A-Za-z0-9._-]{1,64}") String requestId) {
    }

    record ClientLogRequest(@NotNull @Size(max = ClientLogService.MAX_LOGS) List<@Valid @NotNull ClientLog> logs) {
    }

    @PostMapping("/api/v1/client-logs")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    void receive(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody ClientLogRequest request) {
        logs.receive(CurrentUser.id(jwt), request.logs());
    }
}
