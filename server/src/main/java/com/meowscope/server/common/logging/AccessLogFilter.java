package com.meowscope.server.common.logging;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * アクセスログを1リクエストに1行、info で出す（ログ設計書 4章）。
 *
 * <p>パスだけを出し、クエリ文字列は出さない（トークンなどが入るおそれがあるため。6章）。
 * 死活監視の {@code /actuator/health} は数が多く役に立たないので出さない。
 */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE + 1)
public class AccessLogFilter extends OncePerRequestFilter {

    private static final Logger log = LoggerFactory.getLogger(AccessLogFilter.class);

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        return request.getRequestURI().startsWith("/actuator/health");
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        long start = System.nanoTime();
        try {
            chain.doFilter(request, response);
        } finally {
            log.atInfo()
                    .addKeyValue("http.method", request.getMethod())
                    .addKeyValue("http.url_details.path", request.getRequestURI())
                    .addKeyValue("http.status_code", response.getStatus())
                    .addKeyValue("duration", System.nanoTime() - start)
                    .addKeyValue("network.client.ip", request.getRemoteAddr())
                    .log("{} {} {}", request.getMethod(), request.getRequestURI(), response.getStatus());
        }
    }
}
