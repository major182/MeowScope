package com.meowscope.server.common.logging;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.UUID;
import java.util.regex.Pattern;
import org.slf4j.MDC;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * リクエストの ID を決めて、ログ・応答のヘッダー・エラーの本文に付ける（ログ設計書 4章）。
 *
 * <p>他のどのフィルターよりも先に動かし、そのリクエストの間のログすべてに {@code request_id} が付くようにする。
 * 最後に MDC を空にするのもここで行う（スレッドは使い回されるので、残すと別のリクエストのログに混ざる）。
 */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class RequestIdFilter extends OncePerRequestFilter {

    public static final String HEADER = "X-Request-Id";
    public static final String MDC_KEY = "request_id";

    // 端末から来る値は信用しない。ログを壊す改行や長すぎる値を受け取らないよう、使える文字と長さを絞る
    private static final Pattern VALID = Pattern.compile("[A-Za-z0-9._-]{1,64}");

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        String requestId = resolve(request.getHeader(HEADER));
        MDC.put(MDC_KEY, requestId);
        response.setHeader(HEADER, requestId);
        try {
            chain.doFilter(request, response);
        } finally {
            MDC.clear();
        }
    }

    /** 受け取った値が正しければそれを使い、なければ・正しくなければ新しく作る。 */
    static String resolve(String received) {
        if (received != null && VALID.matcher(received).matches()) {
            return received;
        }
        return UUID.randomUUID().toString();
    }

    /** いまのリクエストの ID。エラーの本文に入れるときに使う。 */
    public static String current() {
        return MDC.get(MDC_KEY);
    }
}
