package com.meowscope.server.auth;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import org.slf4j.MDC;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * 認証できたリクエストのログに、利用者の ID（{@code usr.id}）を付ける（ログ設計書 2章）。
 *
 * <p>トークンの検証の直後に動かす。MDC を空にするのは {@link com.meowscope.server.common.logging.RequestIdFilter} が行う。
 */
class UserIdMdcFilter extends OncePerRequestFilter {

    static final String MDC_KEY = "usr.id";

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth instanceof JwtAuthenticationToken jwt) {
            MDC.put(MDC_KEY, jwt.getName());
        }
        chain.doFilter(request, response);
    }
}
