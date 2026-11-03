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
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** おうちの API（API 設計書 4章）。招待と抜ける操作は、おうちの管理の実装（No.12）で足す。 */
@RestController
@RequestMapping("/api/v1/households")
class HouseholdController {

    private final HouseholdService households;

    HouseholdController(HouseholdService households) {
        this.households = households;
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
