package com.meowscope.server.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.Base64;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.NullAndEmptySource;
import org.junit.jupiter.params.provider.ValueSource;

class AuthUnitTest {

    /** 時刻を進められる時計。 */
    static final class MutableClock extends Clock {
        Instant now = Instant.parse("2026-11-03T00:00:00Z");

        @Override
        public ZoneId getZone() {
            return ZoneOffset.UTC;
        }

        @Override
        public Clock withZone(ZoneId zone) {
            return this;
        }

        @Override
        public Instant instant() {
            return now;
        }
    }

    private static final String SECRET = Base64.getEncoder().encodeToString(new byte[32]);

    private static AuthProperties properties() {
        return new AuthProperties(SECRET, Duration.ofMinutes(15), Duration.ofDays(30), 5, Duration.ofMinutes(15));
    }

    @Test
    @DisplayName("UT-AS-01 回数制限：4回の失敗では止めず、5回目で止める（境界値）")
    void 回数の境界() {
        LoginAttemptLimiter limiter = new LoginAttemptLimiter(properties(), new MutableClock());
        for (int i = 0; i < 4; i++) {
            limiter.recordFailure("a@example.com");
        }
        assertThat(limiter.isLocked("a@example.com")).isFalse();
        limiter.recordFailure("A@example.com");
        assertThat(limiter.isLocked("a@EXAMPLE.com")).isTrue();
        assertThat(limiter.isLocked("b@example.com")).isFalse();
    }

    @Test
    @DisplayName("UT-AS-02 回数制限：最初の失敗から15分ちょうどで解除し、その1秒前は止めたまま（境界値）")
    void 時間の境界() {
        MutableClock clock = new MutableClock();
        LoginAttemptLimiter limiter = new LoginAttemptLimiter(properties(), clock);
        Instant start = clock.now;
        for (int i = 0; i < 5; i++) {
            limiter.recordFailure("a@example.com");
        }
        clock.now = start.plus(Duration.ofMinutes(15)).minusSeconds(1);
        assertThat(limiter.isLocked("a@example.com")).isTrue();
        clock.now = start.plus(Duration.ofMinutes(15));
        assertThat(limiter.isLocked("a@example.com")).isFalse();
    }

    @Test
    @DisplayName("UT-AS-03 回数制限：成功で数え直す")
    void 成功で数え直す() {
        LoginAttemptLimiter limiter = new LoginAttemptLimiter(properties(), new MutableClock());
        for (int i = 0; i < 5; i++) {
            limiter.recordFailure("a@example.com");
        }
        limiter.reset("a@example.com");
        assertThat(limiter.isLocked("a@example.com")).isFalse();
    }

    @Test
    @DisplayName("UT-AS-04 署名鍵：32バイトは可（境界値）")
    void 署名鍵の境界_可() {
        assertThat(properties().jwtSecretBytes()).hasSize(32);
    }

    @ParameterizedTest(name = "UT-AS-05 署名鍵：「{0}」は起動させない")
    @NullAndEmptySource
    @ValueSource(strings = {" ", "not base64!", "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=="})
    void 署名鍵の境界_不可(String secret) {
        // 最後の値は 31 バイト（境界値）
        assertThatThrownBy(() -> new AuthProperties(secret, Duration.ZERO, Duration.ZERO, 5, Duration.ZERO))
                .isInstanceOf(IllegalStateException.class);
    }

    @Test
    @DisplayName("UT-AS-06 トークンのハッシュ：同じ値は同じ、違う値は違う。元の値を含まない")
    void ハッシュ() {
        String hash = TokenService.hash("token-a");
        assertThat(hash).isEqualTo(TokenService.hash("token-a")).isNotEqualTo(TokenService.hash("token-b"))
                .hasSize(64).doesNotContain("token-a");
    }
}
