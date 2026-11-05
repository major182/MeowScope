package com.meowscope.server.common.error;

import com.meowscope.server.common.logging.RequestIdFilter;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.ProblemDetail;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.context.request.WebRequest;
import org.springframework.web.servlet.mvc.method.annotation.ResponseEntityExceptionHandler;

/**
 * すべてのエラーを RFC 9457（Problem Details）の形で返す（API 設計書 9章）。
 *
 * <p>Spring の標準の {@link ResponseEntityExceptionHandler} を土台にし、入力の誤りや存在しないパスなど
 * フレームワークが判定するエラーも同じ形にそろえる。本文には {@code code} と {@code requestId} を足す。
 * 想定外の例外は中身を利用者に見せず、ログにだけ詳しく残す。
 */
@RestControllerAdvice
public class ApiExceptionHandler extends ResponseEntityExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(ApiExceptionHandler.class);

    @ExceptionHandler(ApiException.class)
    ResponseEntity<Object> handleApi(ApiException ex, WebRequest request) {
        ErrorCode code = ex.code();
        // 同じ状態コードに複数の種類がある（400 の入力の誤りと確認コードの誤りなど）ので、種類を本文に渡す
        ProblemDetail problem = ProblemDetail.forStatus(code.status());
        problem.setProperty("code", code.name());
        return handleExceptionInternal(ex, problem, new HttpHeaders(), code.status(), request);
    }

    @ExceptionHandler(Exception.class)
    ResponseEntity<Object> handleUnexpected(Exception ex, WebRequest request) {
        log.error("想定外の例外", ex);
        return handleExceptionInternal(ex, null, new HttpHeaders(), ErrorCode.INTERNAL_ERROR.status(), request);
    }

    /** どの経路のエラーも最後にここを通る。本文を設計書の形にそろえる。 */
    @Override
    protected ResponseEntity<Object> createResponseEntity(Object body, HttpHeaders headers,
            HttpStatusCode statusCode, WebRequest request) {
        ProblemDetail problem = body instanceof ProblemDetail given ? given : ProblemDetail.forStatus(statusCode);
        ErrorCode code = problem.getProperties() != null && problem.getProperties().get("code") instanceof String name
                ? ErrorCode.valueOf(name) : ErrorCode.of(statusCode);
        // フレームワークの英語の説明は内部の情報を含むことがあるので、決まった文に置き換える
        problem.setTitle(code.title());
        problem.setDetail(null);
        problem.setProperty("code", code.name());
        problem.setProperty("requestId", RequestIdFilter.current());
        return new ResponseEntity<>(problem, headers, statusCode);
    }
}
