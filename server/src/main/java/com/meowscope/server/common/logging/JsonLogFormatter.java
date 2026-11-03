package com.meowscope.server.common.logging;

import ch.qos.logback.classic.Level;
import ch.qos.logback.classic.spi.ILoggingEvent;
import ch.qos.logback.classic.spi.IThrowableProxy;
import ch.qos.logback.classic.spi.ThrowableProxyUtil;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.slf4j.Marker;
import org.slf4j.event.KeyValuePair;
import org.springframework.boot.json.JsonWriter;
import org.springframework.boot.logging.structured.StructuredLogFormatter;
import org.springframework.core.env.Environment;

/**
 * 1件のログを1行の JSON にする（ログ設計書 1〜3章）。
 *
 * <p>Spring Boot の構造化ログに {@code logging.structured.format.console} でこのクラスを指定して使う。
 * 属性の名前は Datadog がそのまま読める形にそろえ、名前に「.」を含む属性は入れ子にする
 * （例：{@code usr.id} → {@code {"usr":{"id":"..."}}}）。値がない属性は出さない。
 *
 * <p>属性は2か所から集める。リクエストの間ずっと付けたいもの（{@code request_id}・{@code usr.id}）は MDC、
 * そのログだけのもの（アクセスログの {@code http.*} など）は SLF4J の {@code addKeyValue} で渡す。
 */
public class JsonLogFormatter implements StructuredLogFormatter<ILoggingEvent> {

    private final String service;
    private final String env;
    private final String version;

    /** Spring Boot がこのコンストラクタに Environment を渡して作る。 */
    public JsonLogFormatter(Environment environment) {
        this(environment.getProperty("spring.application.name"),
                environment.getProperty("meowscope.env"),
                environment.getProperty("meowscope.version"));
    }

    JsonLogFormatter(String service, String env, String version) {
        this.service = service;
        this.env = env;
        this.version = version;
    }

    @Override
    public String format(ILoggingEvent event) {
        Map<String, Object> root = new LinkedHashMap<>();
        root.put("timestamp", event.getInstant().toString());
        root.put("status", status(event));
        root.put("message", event.getFormattedMessage());
        put(root, "service", service);
        put(root, "env", env);
        put(root, "version", version);
        put(root, "logger.name", event.getLoggerName());
        put(root, "logger.thread_name", event.getThreadName());
        event.getMDCPropertyMap().forEach((key, value) -> put(root, key, value));
        List<KeyValuePair> pairs = event.getKeyValuePairs();
        if (pairs != null) {
            pairs.forEach(pair -> put(root, pair.key, pair.value));
        }
        IThrowableProxy error = event.getThrowableProxy();
        if (error != null) {
            put(root, "error.kind", error.getClassName());
            put(root, "error.message", error.getMessage());
            put(root, "error.stack", ThrowableProxyUtil.asString(error));
        }
        return JsonWriter.standard().writeToString(root) + "\n";
    }

    /** SLF4J の重大度とマーカーから、設計書の6段階の値を決める。 */
    static String status(ILoggingEvent event) {
        List<Marker> markers = event.getMarkerList();
        boolean alert = has(markers, Severity.ALERT);
        boolean critical = has(markers, Severity.CRITICAL);
        Level level = event.getLevel();
        if (level == Level.ERROR) {
            return alert ? "alert" : critical ? "critical" : "error";
        }
        if (level == Level.WARN) {
            return "warning";
        }
        if (level == Level.INFO) {
            return has(markers, Severity.NOTICE) ? "notice" : "info";
        }
        return "debug";
    }

    private static boolean has(List<Marker> markers, Marker marker) {
        return markers != null && markers.contains(marker);
    }

    /** 「.」で区切った名前を入れ子のオブジェクトにして入れる。値が空なら入れない。 */
    @SuppressWarnings("unchecked")
    static void put(Map<String, Object> root, String key, Object value) {
        if (value == null || key == null || key.isEmpty()) {
            return;
        }
        String[] parts = key.split("\\.");
        Map<String, Object> current = root;
        for (int i = 0; i < parts.length - 1; i++) {
            Object child = current.get(parts[i]);
            if (!(child instanceof Map)) {
                child = new LinkedHashMap<String, Object>();
                current.put(parts[i], child);
            }
            current = (Map<String, Object>) child;
        }
        current.put(parts[parts.length - 1], value);
    }
}
