package com.meowscope.server.household;

import com.meowscope.server.auth.CurrentUser;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** 招待の API（API 設計書 4章）。 */
@RestController
class InvitationController {

    private final InvitationService invitations;

    InvitationController(InvitationService invitations) {
        this.invitations = invitations;
    }

    record AcceptRequest(@NotBlank @Size(max = 100) String token) {
    }

    record AcceptResponse(UUID householdId) {
    }

    @PostMapping("/api/v1/households/{id}/invitations")
    @ResponseStatus(HttpStatus.CREATED)
    InvitationService.Invitation create(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id) {
        return invitations.create(CurrentUser.id(jwt), id);
    }

    @PostMapping("/api/v1/invitations/accept")
    AcceptResponse accept(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody AcceptRequest request) {
        return new AcceptResponse(invitations.accept(CurrentUser.id(jwt), request.token()));
    }
}
