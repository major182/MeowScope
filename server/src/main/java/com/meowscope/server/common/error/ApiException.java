package com.meowscope.server.common.error;

/**
 * 業務のルールで処理を止めるときに投げる例外。{@link ApiExceptionHandler} がエラーの本文に変える。
 *
 * <p>例：{@code throw new ApiException(ErrorCode.CONFLICT)}（メールアドレスの重複）。
 */
public class ApiException extends RuntimeException {

    private final ErrorCode code;

    public ApiException(ErrorCode code) {
        super(code.name());
        this.code = code;
    }

    public ErrorCode code() {
        return code;
    }
}
