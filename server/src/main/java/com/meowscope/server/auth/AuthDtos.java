package com.meowscope.server.auth;

import com.meowscope.server.user.UserResponse;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * 認証の API の要求と応答（API 設計書 2章）。入力はサーバーでも必ず検証する（NF-SC-08）。
 *
 * <p>メールアドレスとパスワードは半角の英数字と記号だけを受け付ける（BR-26：全角を受け付けない）。
 */
public final class AuthDtos {

    /** 半角の英数字と記号（空白を含まない）。 */
    static final String ASCII = "^[\\x21-\\x7E]+$";

    private AuthDtos() {
    }

    /**
     * 新規登録。パスワードの上限 64 文字は、bcrypt が 72 バイトまでしか使わないことに余裕を持たせた値。
     */
    public record RegisterRequest(
            @NotBlank @Email @Size(max = 254) @Pattern(regexp = ASCII) String email,
            @NotNull @Size(min = 8, max = 64) @Pattern(regexp = ASCII) String password,
            @NotBlank @Size(max = 20) String displayName) {
    }

    public record LoginRequest(
            @NotBlank @Size(max = 254) String email,
            @NotBlank @Size(max = 64) String password) {
    }

    public record RefreshRequest(@NotBlank @Size(max = 100) String refreshToken) {
    }

    /** パスワードの再設定の受付。 */
    public record PasswordResetRequest(@NotBlank @Size(max = 254) String email) {
    }

    /** パスワードの再設定の実行。コードは6桁の数字、新しいパスワードは新規登録と同じ決まり。 */
    public record PasswordResetConfirm(
            @NotBlank @Size(max = 254) String email,
            @NotNull @Pattern(regexp = "^[0-9]{6}$") String code,
            @NotNull @Size(min = 8, max = 64) @Pattern(regexp = ASCII) String newPassword) {
    }

    /** ログイン・新規登録・更新の応答。 */
    public record AuthResponse(String accessToken, String refreshToken, long expiresIn, UserResponse user) {
    }
}
