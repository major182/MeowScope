package com.meowscope.server.household;

import com.meowscope.server.auth.CurrentUser;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** おうちの API（API 設計書 4章）。招待はリンクで行い、メールでの招待はしない。 */
@RestController
@RequestMapping("/api/v1/households")
class HouseholdController {

    private final HouseholdService households;
    private final LeaveService leave;

    HouseholdController(HouseholdService households, LeaveService leave) {
        this.households = households;
        this.leave = leave;
    }

    /** 抜けるときの選択。記録を残すか（BR-16）。 */
    record LeaveRequest(@NotNull Boolean keepRecords) {
    }

    /** 抜けた結果。最後の1人で、おうちごと消したら householdDeleted が真（BR-19）。 */
    record LeaveResponse(boolean householdDeleted) {
    }

    @PostMapping("/{id}/leave")
    LeaveResponse leave(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id,
            @Valid @RequestBody LeaveRequest request) {
        return new LeaveResponse(leave.leave(CurrentUser.id(jwt), id, request.keepRecords()));
    }

    /** 端末で作った記録項目。標準の8項目を受け取る。 */
    record RecordTypeInput(
            @NotNull UUID id,
            @NotBlank @Size(max = 20) String name,
            @Size(max = 50) String icon,
            @NotNull @Pattern(regexp = "food|water|medicine|urine|stool|vomit|weight|brushing|custom") String kind,
            @Min(0) @Max(1000) int sortOrder) {
    }

    record CreateRequest(
            @NotNull UUID id,
            @NotBlank @Size(max = 50) String name,
            @NotNull @Size(max = 20) List<@Valid @NotNull RecordTypeInput> recordTypes) {
    }

    record CreateResponse(UUID id) {
    }

    /** 端末で作ったおうちを登録する。送り直されたとき（通信が切れた後など）は 200 で同じ結果を返す。 */
    @PostMapping
    ResponseEntity<CreateResponse> create(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody CreateRequest request) {
        boolean created = households.create(CurrentUser.id(jwt), request);
        return ResponseEntity.status(created ? HttpStatus.CREATED : HttpStatus.OK)
                .body(new CreateResponse(request.id()));
    }
}
