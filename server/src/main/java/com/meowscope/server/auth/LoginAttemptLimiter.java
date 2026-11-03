package com.meowscope.server.auth;

import java.time.Clock;
import java.time.Instant;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.Locale;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.stereotype.Component;

/**
 * ログインの失敗を数え、続けて失敗したら一定の時間ログインを止める（NF-SC-03：総当たり攻撃を防ぐ）。
 *
 * <p>メールアドレスごとに、直近 {@code loginLockDuration} の失敗の時刻を持つ。
 * 回数が {@code loginMaxFailures} に達したら、最も古い失敗から {@code loginLockDuration} が過ぎるまで止める。
 * 利用者は2人でサーバーも1台なので、メモリーに持つ（再起動で数え直しになるのは許容する）。
 */
@Component
class LoginAttemptLimiter {

    private final Map<String, Deque<Instant>> failures = new ConcurrentHashMap<>();
    private final AuthProperties properties;
    private final Clock clock;

    LoginAttemptLimiter(AuthProperties properties, Clock clock) {
        this.properties = properties;
        this.clock = clock;
    }

    boolean isLocked(String email) {
        Deque<Instant> list = failures.get(key(email));
        if (list == null) {
            return false;
        }
        synchronized (list) {
            dropOld(list);
            return list.size() >= properties.loginMaxFailures();
        }
    }

    void recordFailure(String email) {
        Deque<Instant> list = failures.computeIfAbsent(key(email), k -> new ArrayDeque<>());
        synchronized (list) {
            dropOld(list);
            list.addLast(clock.instant());
        }
    }

    /** ログインに成功したら数え直す。 */
    void reset(String email) {
        failures.remove(key(email));
    }

    private void dropOld(Deque<Instant> list) {
        Instant from = clock.instant().minus(properties.loginLockDuration());
        while (!list.isEmpty() && !list.peekFirst().isAfter(from)) {
            list.removeFirst();
        }
    }

    private static String key(String email) {
        return email.toLowerCase(Locale.ROOT);
    }
}
