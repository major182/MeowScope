package com.meowscope.server.auth;

import com.meowscope.server.common.error.ApiException;
import com.meowscope.server.common.error.ErrorCode;
import java.time.Clock;
import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.factory.PasswordEncoderFactories;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.security.oauth2.jwt.NimbusJwtEncoder;
import org.springframework.security.oauth2.server.resource.web.authentication.BearerTokenAuthenticationFilter;
import org.springframework.security.web.access.AccessDeniedHandler;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.web.servlet.HandlerExceptionResolver;

/**
 * 認証と認可の設定（API 設計書 1〜2章、NF-SC-04）。
 *
 * <p>アクセストークンは JWT で、Spring Security の OAuth2 Resource Server が毎回署名と期限を確かめる（DB は見ない）。
 * トークンだけで認証するので、ログインの状態をサーバーに持たず（STATELESS）、Cookie を使わないので CSRF の対策は要らない。
 * 認証の失敗も {@link com.meowscope.server.common.error.ApiExceptionHandler} に渡し、他のエラーと同じ形で返す。
 */
@Configuration
@EnableConfigurationProperties(AuthProperties.class)
public class SecurityConfig {

    /** 認証なしで呼べる API。ほかはすべて認証が必要。 */
    private static final String[] PUBLIC_POSTS = {
        "/api/v1/auth/register", "/api/v1/auth/login", "/api/v1/auth/refresh",
    };

    @Bean
    SecurityFilterChain securityFilterChain(HttpSecurity http,
            @Qualifier("handlerExceptionResolver") HandlerExceptionResolver resolver) throws Exception {
        AuthenticationEntryPoint unauthorized = (request, response, ex) ->
                resolver.resolveException(request, response, null, new ApiException(ErrorCode.UNAUTHORIZED));
        AccessDeniedHandler forbidden = (request, response, ex) ->
                resolver.resolveException(request, response, null, new ApiException(ErrorCode.FORBIDDEN));
        http.csrf(csrf -> csrf.disable())
                .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(auth -> auth
                        .requestMatchers(HttpMethod.POST, PUBLIC_POSTS).permitAll()
                        .requestMatchers("/actuator/health", "/actuator/health/**", "/error").permitAll()
                        .anyRequest().authenticated())
                .oauth2ResourceServer(oauth -> oauth.jwt(Customizer.withDefaults())
                        .authenticationEntryPoint(unauthorized)
                        .accessDeniedHandler(forbidden))
                .exceptionHandling(handling -> handling
                        .authenticationEntryPoint(unauthorized)
                        .accessDeniedHandler(forbidden))
                .addFilterAfter(new UserIdMdcFilter(), BearerTokenAuthenticationFilter.class);
        return http.build();
    }

    @Bean
    SecretKey jwtKey(AuthProperties properties) {
        return new SecretKeySpec(properties.jwtSecretBytes(), "HmacSHA256");
    }

    @Bean
    JwtDecoder jwtDecoder(SecretKey jwtKey) {
        return NimbusJwtDecoder.withSecretKey(jwtKey).macAlgorithm(MacAlgorithm.HS256).build();
    }

    @Bean
    JwtEncoder jwtEncoder(SecretKey jwtKey) {
        return NimbusJwtEncoder.withSecretKey(jwtKey).build();
    }

    /** パスワードのハッシュ（NF-SC-02）。Spring Security の標準で、今は bcrypt を使う。 */
    @Bean
    PasswordEncoder passwordEncoder() {
        return PasswordEncoderFactories.createDelegatingPasswordEncoder();
    }

    /** 時刻の取得。テストで時刻を進められるよう、Bean にして差し替えられるようにする。 */
    @Bean
    Clock clock() {
        return Clock.systemUTC();
    }
}
