package com.meowscope.server.common.logging;

import static org.assertj.core.api.Assertions.assertThat;

import ch.qos.logback.classic.Level;
import ch.qos.logback.classic.spi.LoggingEvent;
import ch.qos.logback.classic.spi.ThrowableProxy;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.slf4j.MarkerFactory;
import org.slf4j.event.KeyValuePair;
import org.springframework.boot.json.JsonParserFactory;
import org.springframework.mock.env.MockEnvironment;

class JsonLogFormatterTest {

    private final JsonLogFormatter formatter = new JsonLogFormatter("meowscope-server", "ci", "1.0.0");

    private static LoggingEvent event(Level level, String message) {
        return event(level, message, Map.of());
    }

    // ログの仕組みにつながない単独のイベントなので、MDC は渡した Map を入れる
    private static LoggingEvent event(Level level, String message, Map<String, String> mdc) {
        LoggingEvent event = new LoggingEvent();
        event.setLevel(level);
        event.setMessage(message);
        event.setLoggerName("com.example.Sample");
        event.setThreadName("main");
        event.setMDCPropertyMap(mdc);
        event.setInstant(Instant.parse("2026-11-03T01:02:03Z"));
        return event;
    }

    private static Map<String, Object> parse(String json) {
        return JsonParserFactory.getJsonParser().parseMap(json);
    }

    @Test
    @DisplayName("UT-LG-01 1件を1行の JSON にし、基本の属性を出す")
    void 基本の属性() {
        String json = formatter.format(event(Level.INFO, "こんにちは"));
        assertThat(json).endsWith("\n");
        assertThat(json.strip()).doesNotContain("\n");
        Map<String, Object> map = parse(json);
        assertThat(map).containsEntry("timestamp", "2026-11-03T01:02:03Z")
                .containsEntry("status", "info")
                .containsEntry("message", "こんにちは")
                .containsEntry("service", "meowscope-server")
                .containsEntry("env", "ci")
                .containsEntry("version", "1.0.0")
                .containsEntry("logger", Map.of("name", "com.example.Sample", "thread_name", "main"));
    }

    @ParameterizedTest(name = "UT-LG-02 {0} とマーカー {1} は {2}")
    @CsvSource({
        "ERROR, ALERT, alert",
        "ERROR, CRITICAL, critical",
        "ERROR, , error",
        "WARN, , warning",
        "INFO, NOTICE, notice",
        "INFO, , info",
        "DEBUG, , debug",
        "INFO, OTHER, info",
    })
    void 重大度(String level, String marker, String expected) {
        LoggingEvent event = event(Level.toLevel(level), "x");
        if (marker != null) {
            event.addMarker(MarkerFactory.getMarker(marker));
        }
        assertThat(JsonLogFormatter.status(event)).isEqualTo(expected);
    }

    @Test
    @DisplayName("UT-LG-03 MDC と addKeyValue の「.」を含む名前は入れ子にする")
    void 入れ子() {
        LoggingEvent event = event(Level.INFO, "x", Map.of("request_id", "r1", "usr.id", "u1"));
        event.addKeyValuePair(new KeyValuePair("http.status_code", 200));
        event.addKeyValuePair(new KeyValuePair("http.method", "GET"));
        Map<String, Object> map = parse(formatter.format(event));
        assertThat(map).containsEntry("request_id", "r1")
                .containsEntry("usr", Map.of("id", "u1"))
                .containsEntry("http", Map.of("status_code", 200, "method", "GET"));
    }

    @Test
    @DisplayName("UT-LG-04 値のない属性は出さない")
    void 値がない属性() {
        JsonLogFormatter empty = new JsonLogFormatter(new MockEnvironment());
        LoggingEvent event = event(Level.INFO, "x");
        Map<String, Object> map = parse(empty.format(event));
        assertThat(map).doesNotContainKeys("service", "env", "version", "error", "request_id", "usr");
    }

    @Test
    @DisplayName("UT-LG-05 例外の種類・文・スタックを出す")
    void 例外() {
        LoggingEvent event = event(Level.ERROR, "失敗");
        event.setThrowableProxy(new ThrowableProxy(new IllegalStateException("壊れた")));
        Map<String, Object> map = parse(formatter.format(event));
        @SuppressWarnings("unchecked")
        Map<String, Object> error = (Map<String, Object>) map.get("error");
        assertThat(error).containsEntry("kind", "java.lang.IllegalStateException")
                .containsEntry("message", "壊れた");
        assertThat((String) error.get("stack")).contains("IllegalStateException").contains("JsonLogFormatterTest");
    }

    @Test
    @DisplayName("UT-LG-06 入れ子の途中に値があれば、オブジェクトで置き換える。空の名前は無視する")
    void 入れ子の衝突() {
        Map<String, Object> root = new LinkedHashMap<>();
        JsonLogFormatter.put(root, "usr", "x");
        JsonLogFormatter.put(root, "usr.id", "u1");
        JsonLogFormatter.put(root, "", "y");
        JsonLogFormatter.put(root, null, "y");
        assertThat(root).isEqualTo(Map.of("usr", Map.of("id", "u1")));
    }
}
