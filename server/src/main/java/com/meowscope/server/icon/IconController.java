package com.meowscope.server.icon;

import com.meowscope.server.auth.CurrentUser;
import com.meowscope.server.photo.PhotoService;
import jakarta.servlet.http.HttpServletRequest;
import java.io.IOException;
import java.util.UUID;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RestController;

/** アイコンの送信と取得（API 設計書 3章・6章）。本文は画像そのもの。 */
@RestController
class IconController {

    private final IconService icons;

    IconController(IconService icons) {
        this.icons = icons;
    }

    @PutMapping(value = "/api/v1/me/icon", consumes = {MediaType.IMAGE_JPEG_VALUE, MediaType.IMAGE_PNG_VALUE,
        "image/webp"})
    ResponseEntity<Void> uploadMine(@AuthenticationPrincipal Jwt jwt, HttpServletRequest request) throws IOException {
        icons.uploadUser(CurrentUser.id(jwt), request.getInputStream());
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/api/v1/users/{id}/icon")
    ResponseEntity<byte[]> user(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id) throws IOException {
        return image(icons.downloadUser(CurrentUser.id(jwt), id));
    }

    @PutMapping(value = "/api/v1/cats/{id}/icon", consumes = {MediaType.IMAGE_JPEG_VALUE, MediaType.IMAGE_PNG_VALUE,
        "image/webp"})
    ResponseEntity<Void> uploadCat(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id, HttpServletRequest request)
            throws IOException {
        icons.uploadCat(CurrentUser.id(jwt), id, request.getInputStream());
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/api/v1/cats/{id}/icon")
    ResponseEntity<byte[]> cat(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id) throws IOException {
        return image(icons.downloadCat(CurrentUser.id(jwt), id));
    }

    private static ResponseEntity<byte[]> image(byte[] bytes) {
        return ResponseEntity.ok().contentType(PhotoService.typeOf(bytes)).body(bytes);
    }
}
