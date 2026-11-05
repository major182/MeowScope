package com.meowscope.server.common.logging;

import static org.assertj.core.api.Assertions.assertThat;

import ch.qos.logback.classic.Level;
import ch.qos.logback.classic.spi.LoggingEvent;
import ch.qos.logback.classic.spi.ThrowableProxy;
import java.time.Instant;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;

class LogMaskingTest {

    @ParameterizedTest(name = "{0}")
    @CsvSource(delimiter = '|', value = {
        "メールアドレス|Invalid Addresses: haru@example.com|Invalid Addresses: ***@***",
        "山かっこの中|<natsu.k+1@mail.example.jp>|<***@***>",
        "PostgreSQL の詳細|ERROR: duplicate key<br>  Detail: Key (name)=(ミケ) already exists.|ERROR: duplicate key<br>  Detail: ***",
        "日本語の詳細|ERROR: 重複<br>  詳細: キー (memo)=(完食)|ERROR: 重複<br>  詳細: ***",
        "制約に反した行|Failing row contains (1, ミケ, 完食).|Failing row contains (***).",
        "伏せるものがない|connection refused|connection refused",
    })
    @DisplayName("UT-LG-12 メールアドレス・DB のエラーの行の値を伏せ、ほかの文は変えない")
    void 伏せる(String name, String given, String expected) {
        // CSV の1行に収めるため、改行は <br> と書く
        assertThat(LogMasking.mask(given.replace("<br>", "\n"))).isEqualTo(expected.replace("<br>", "\n"));
    }

    @Test
    @DisplayName("UT-LG-13 境界値：空と null はそのまま返す")
    void 空() {
        assertThat(LogMasking.mask(null)).isNull();
        assertThat(LogMasking.mask("")).isEmpty();
    }

    @Test
    @DisplayName("UT-LG-14 想定外の例外のログ：文・例外の文・積み重ねのどれにも、メールアドレスと行の値を出さない（AC-19）")
    void 例外のログ() {
        LoggingEvent event = new LoggingEvent();
        event.setLevel(Level.ERROR);
        event.setLoggerName("test");
        event.setThreadName("main");
        event.setMDCPropertyMap(java.util.Map.of());
        event.setInstant(Instant.parse("2026-11-06T00:00:00Z"));
        event.setMessage("送れない：haru@example.com");
        RuntimeException cause = new RuntimeException("Detail: Key (memo)=(完食) already exists.");
        event.setThrowableProxy(new ThrowableProxy(new IllegalStateException("to natsu@example.com", cause)));

        String json = new JsonLogFormatter("meowscope-server", "test", "dev").format(event);

        assertThat(json).doesNotContain("haru@example.com").doesNotContain("natsu@example.com")
                .doesNotContain("完食").contains("***@***").contains("IllegalStateException");
    }
}
