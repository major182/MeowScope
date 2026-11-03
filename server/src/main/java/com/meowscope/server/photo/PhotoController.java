package com.meowscope.server.photo;

import com.meowscope.server.auth.CurrentUser;
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
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** 写真の送信と取得（API 設計書 6章）。 */
@RestController
@RequestMapping("/api/v1/photos")
class PhotoController {

    private final PhotoService photos;

    PhotoController(PhotoService photos) {
        this.photos = photos;
    }

    /** 画像の本体をそのまま本文で受け取る。形式は Content-Type と、ファイルの先頭の印の両方で確かめる。 */
    @PutMapping(value = "/{id}", consumes = {MediaType.IMAGE_JPEG_VALUE, MediaType.IMAGE_PNG_VALUE, "image/webp"})
    ResponseEntity<Void> upload(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id, HttpServletRequest request)
            throws IOException {
        photos.upload(CurrentUser.id(jwt), id, request.getInputStream());
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/{id}")
    ResponseEntity<byte[]> download(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id) throws IOException {
        byte[] bytes = photos.download(CurrentUser.id(jwt), id);
        return ResponseEntity.ok().contentType(PhotoService.typeOf(bytes)).body(bytes);
    }
}
