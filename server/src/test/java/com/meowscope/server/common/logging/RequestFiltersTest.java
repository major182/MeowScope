package com.meowscope.server.common.logging;

import static org.assertj.core.api.Assertions.assertThat;

import ch.qos.logback.classic.Logger;
import ch.qos.logback.classic.spi.ILoggingEvent;
import ch.qos.logback.core.read.ListAppender;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.NullAndEmptySource;
import org.junit.jupiter.params.provider.ValueSource;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

class RequestFiltersTest {

    private final Logger accessLogger = (Logger) LoggerFactory.getLogger(AccessLogFilter.class);
    private final ListAppender<ILoggingEvent> appender = new ListAppender<>();

    @BeforeEach
    void setUp() {
        appender.start();
        accessLogger.addAppender(appender);
    }

    @AfterEach
    void tearDown() {
        accessLogger.detachAppender(appender);
    }

    @ParameterizedTest(name = "UT-LG-07 正しい ID「{0}」はそのまま使う")
    @ValueSource(strings = {"a", "req_1.2-3", "0123456789012345678901234567890123456789012345678901234567890123"})
    void 正しいID(String id) {
        assertThat(RequestIdFilter.resolve(id)).isEqualTo(id);
    }

    @ParameterizedTest(name = "UT-LG-08 正しくない ID「{0}」は作り直す")
    @NullAndEmptySource
    @ValueSource(strings = {"a b", "x\ny", "x/y", "01234567890123456789012345678901234567890123456789012345678901234"})
    void 正しくないID(String id) {
        assertThat(RequestIdFilter.resolve(id)).isNotEqualTo(id).hasSize(36);
    }

    @Test
    @DisplayName("UT-LG-09 処理の間は MDC に ID を置き、応答のヘッダーで返し、終わったら MDC を空にする")
    void MDCとヘッダー() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/x");
        request.addHeader("X-Request-Id", "abc");
        MockHttpServletResponse response = new MockHttpServletResponse();
        AtomicReference<String> during = new AtomicReference<>();
        new RequestIdFilter().doFilter(request, response, (req, res) -> {
            during.set(RequestIdFilter.current());
            MDC.put("usr.id", "u1");
        });
        assertThat(during.get()).isEqualTo("abc");
        assertThat(response.getHeader("X-Request-Id")).isEqualTo("abc");
        assertThat(MDC.getCopyOfContextMap()).isNullOrEmpty();
    }

    @Test
    @DisplayName("UT-LG-10 アクセスログを1行 info で出し、クエリ文字列は出さない")
    void アクセスログ() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("POST", "/api/v1/sync");
        request.setQueryString("token=secret");
        MockHttpServletResponse response = new MockHttpServletResponse();
        response.setStatus(201);
        new AccessLogFilter().doFilter(request, response, new MockFilterChain());
        assertThat(appender.list).hasSize(1);
        ILoggingEvent event = appender.list.get(0);
        assertThat(event.getLevel().toString()).isEqualTo("INFO");
        Map<String, Object> pairs = new HashMap<>();
        event.getKeyValuePairs().forEach(pair -> pairs.put(pair.key, pair.value));
        assertThat(pairs).containsEntry("http.method", "POST")
                .containsEntry("http.url_details.path", "/api/v1/sync")
                .containsEntry("http.status_code", 201)
                .containsKeys("duration", "network.client.ip");
        assertThat(event.getFormattedMessage()).doesNotContain("secret");
    }

    @Test
    @DisplayName("UT-LG-11 死活監視のアクセスログは出さない")
    void 死活監視は出さない() throws Exception {
        new AccessLogFilter().doFilter(new MockHttpServletRequest("GET", "/actuator/health"),
                new MockHttpServletResponse(), new MockFilterChain());
        assertThat(appender.list).isEmpty();
    }
}
