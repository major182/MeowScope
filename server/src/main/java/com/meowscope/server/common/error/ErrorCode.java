package com.meowscope.server.common.error;

import org.springframework.http.HttpStatus;
import org.springframework.http.HttpStatusCode;

/**
 * エラーの本文の {@code code} と {@code title}（API 設計書 9章）。
 *
 * <p>アプリは {@code code} を見て画面の文を決める。{@code title} は人が読むための文で、画面にはそのまま出さない。
 */
public enum ErrorCode {
    VALIDATION_ERROR(HttpStatus.BAD_REQUEST, "入力内容に誤りがあります"),
    UNAUTHORIZED(HttpStatus.UNAUTHORIZED, "ログインが必要です"),
    FORBIDDEN(HttpStatus.FORBIDDEN, "この操作は許可されていません"),
    NOT_FOUND(HttpStatus.NOT_FOUND, "見つかりません"),
    METHOD_NOT_ALLOWED(HttpStatus.METHOD_NOT_ALLOWED, "この方法では呼び出せません"),
    CONFLICT(HttpStatus.CONFLICT, "すでに登録されています"),
    PAYLOAD_TOO_LARGE(HttpStatus.CONTENT_TOO_LARGE, "容量が大きすぎます"),
    UNSUPPORTED_MEDIA_TYPE(HttpStatus.UNSUPPORTED_MEDIA_TYPE, "この形式には対応していません"),
    TOO_MANY_REQUESTS(HttpStatus.TOO_MANY_REQUESTS, "回数の上限に達しました。しばらく待ってからやり直してください"),
    INTERNAL_ERROR(HttpStatus.INTERNAL_SERVER_ERROR, "サーバーで問題が発生しました");

    private final HttpStatus status;
    private final String title;

    ErrorCode(HttpStatus status, String title) {
        this.status = status;
        this.title = title;
    }

    public HttpStatus status() {
        return status;
    }

    public String title() {
        return title;
    }

    /** フレームワークが決めた状態コードに合う code を選ぶ。合うものがなければ、4xx は入力の誤り、5xx はサーバーの異常とする。 */
    public static ErrorCode of(HttpStatusCode status) {
        for (ErrorCode code : values()) {
            if (code.status.value() == status.value()) {
                return code;
            }
        }
        return status.is5xxServerError() ? INTERNAL_ERROR : VALIDATION_ERROR;
    }
}
