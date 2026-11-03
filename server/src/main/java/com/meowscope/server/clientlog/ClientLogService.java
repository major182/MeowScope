package com.meowscope.server.clientlog;

import com.meowscope.server.common.error.ApiException;
import com.meowscope.server.common.error.ErrorCode;
import com.meowscope.server.common.logging.Severity;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.regex.Pattern;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.spi.LoggingEventBuilder;
import org.springframework.stereotype.Service;

/**
 * 端末のログを、サーバーのログと同じ標準出力へ出す（ログ設計書 8章）。
 *
 * <ul>
 *   <li>ロガーの名前は {@code client}。重大度は端末の値を保つ
 *   <li>信頼できない入力として扱い、改行と制御文字を除き、許可した属性だけを出す
 *   <li>メールアドレスに見える文字列は伏せる（ログ設計書 6章。端末でも伏せるが、念のためここでも）
 *   <li>利用者の ID は端末の申告ではなく、トークンから付ける（MDC の usr.id）
 *   <li>1人あたり1時間に60回まで。超えたら 429
 * </ul>
 */
@Service
class ClientLogService {

    static final int MAX_LOGS = 100;
    /** 1件 8KB まで。文字数で数える（全角を含めても 8KB を大きく超えないよう、余裕を持たせた値）。 */
    static final int MAX_MESSAGE = 2000;
    static final int MAX_CALLS_PER_HOUR = 60;

    // 端末のログは、このクラスの名前ではなく client というロガーで出す（ログ設計書 8章）
    private static final Logger log = LoggerFactory.getLogger("client");
    private static final Pattern CONTROL = Pattern.compile("[\\p{Cntrl}\\u2028\\u2029]+");
    private static final Pattern EMAIL = Pattern.compile("[^\\s@]+@[^\\s@]+\\.[^\\s@]+");

    private final Map<UUID, Deque<Instant>> calls = new ConcurrentHashMap<>();
    private final Clock clock;

    ClientLogService(Clock clock) {
        this.clock = clock;
    }

    void receive(UUID userId, List<ClientLogController.ClientLog> logs) {
        checkRate(userId);
        for (ClientLogController.ClientLog entry : logs) {
            LoggingEventBuilder event = switch (entry.status()) {
                case "critical" -> log.atError().addMarker(Severity.CRITICAL);
                case "error" -> log.atError();
                case "warning" -> log.atWarn();
                case "notice" -> log.atInfo().addMarker(Severity.NOTICE);
                default -> log.atInfo();
            };
            put(event, "client.platform", entry.platform());
            put(event, "client.app_version", clean(entry.appVersion()));
            put(event, "client.os_version", clean(entry.osVersion()));
            put(event, "client.occurred_at", clean(entry.occurredAt()));
            put(event, "client.request_id", entry.requestId());
            event.log(clean(entry.message()));
        }
    }

    private static void put(LoggingEventBuilder event, String key, String value) {
        if (value != null) {
            event.addKeyValue(key, value);
        }
    }

    /** 改行と制御文字を空白に置き換え（ログの行を偽装させない）、メールアドレスを伏せる。 */
    static String clean(String value) {
        if (value == null) {
            return null;
        }
        return EMAIL.matcher(CONTROL.matcher(value).replaceAll(" ")).replaceAll("***@***");
    }

    private void checkRate(UUID userId) {
        Deque<Instant> list = calls.computeIfAbsent(userId, k -> new ArrayDeque<>());
        Instant now = clock.instant();
        synchronized (list) {
            while (!list.isEmpty() && !list.peekFirst().isAfter(now.minus(Duration.ofHours(1)))) {
                list.removeFirst();
            }
            if (list.size() >= MAX_CALLS_PER_HOUR) {
                throw new ApiException(ErrorCode.TOO_MANY_REQUESTS);
            }
            list.addLast(now);
        }
    }
}
