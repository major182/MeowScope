package com.meowscope.server.sync;

import java.math.BigDecimal;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.LocalDate;
import java.time.format.DateTimeParseException;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import tools.jackson.databind.json.JsonMapper;

/**
 * 同期の {@code data}（端末から来た JSON）から値を取り出し、型と範囲を確かめる（NF-SC-08）。
 *
 * <p>端末は解析される前提なので、どの値も信用しない。誤りがあれば {@link Rejected} を投げ、その変更だけを
 * {@code rejected} にする（ほかの変更の反映は続ける）。
 */
final class Fields {

    private final Map<String, Object> data;
    private final JsonMapper json;

    Fields(Map<String, Object> data, JsonMapper json) {
        this.data = data == null ? Map.of() : data;
        this.json = json;
    }

    /** 文字列。空白だけは空として扱う。 */
    String text(String name, boolean required, int max) {
        Object value = data.get(name);
        if (value == null || (value instanceof String s && s.isBlank())) {
            if (required) {
                throw new Rejected("invalid", name);
            }
            return null;
        }
        if (!(value instanceof String s) || s.length() > max) {
            throw new Rejected("invalid", name);
        }
        return s.strip();
    }

    /** 決まった値のどれか。 */
    String oneOf(String name, boolean required, Set<String> allowed) {
        String value = text(name, required, 50);
        if (value != null && !allowed.contains(value)) {
            throw new Rejected("invalid", name);
        }
        return value;
    }

    UUID uuid(String name) {
        try {
            return UUID.fromString(text(name, true, 36));
        } catch (IllegalArgumentException e) {
            throw new Rejected("invalid", name);
        }
    }

    Timestamp instant(String name, boolean required) {
        String value = text(name, required, 40);
        return value == null ? null : parseInstant(value, name);
    }

    static Timestamp parseInstant(String value, String name) {
        try {
            return Timestamp.from(Instant.parse(value));
        } catch (DateTimeParseException e) {
            throw new Rejected("invalid", name);
        }
    }

    /** 日付。端末は時刻つきで送ることがあるので、先頭の「年-月-日」だけを使う。 */
    LocalDate date(String name) {
        String value = text(name, false, 40);
        if (value == null) {
            return null;
        }
        try {
            return LocalDate.parse(value.length() > 10 ? value.substring(0, 10) : value);
        } catch (DateTimeParseException e) {
            throw new Rejected("invalid", name);
        }
    }

    Integer integer(String name, int min, int max) {
        Object value = data.get(name);
        if (value == null) {
            return null;
        }
        if (!(value instanceof Integer i) || i < min || i > max) {
            throw new Rejected("invalid", name);
        }
        return i;
    }

    BigDecimal number(String name, double min, double max) {
        Object value = data.get(name);
        if (value == null) {
            return null;
        }
        if (!(value instanceof Number n) || n.doubleValue() < min || n.doubleValue() > max) {
            throw new Rejected("invalid", name);
        }
        return new BigDecimal(n.toString());
    }

    boolean bool(String name) {
        Object value = data.get(name);
        if (value == null) {
            return false;
        }
        if (!(value instanceof Boolean b)) {
            throw new Rejected("invalid", name);
        }
        return b;
    }

    /** JSON のオブジェクト。DB の jsonb に入れる文字列にする。端末が文字列で送ってきた JSON も受け付ける。 */
    String object(String name, int maxLength) {
        Object value = data.get(name);
        if (value == null) {
            return null;
        }
        Object parsed = value;
        if (value instanceof String s) {
            try {
                parsed = json.readValue(s, Object.class);
            } catch (RuntimeException e) {
                throw new Rejected("invalid", name);
            }
        }
        if (!(parsed instanceof Map)) {
            throw new Rejected("invalid", name);
        }
        String text = json.writeValueAsString(parsed);
        if (text.length() > maxLength) {
            throw new Rejected("invalid", name);
        }
        return text;
    }

    /** 変更を受け付けないときの理由。ログの {@code evt.reason} に出す（内容は出さない）。 */
    static final class Rejected extends RuntimeException {
        private final String reason;
        private final String field;

        Rejected(String reason, String field) {
            super(field == null ? reason : reason + ":" + field);
            this.reason = reason;
            this.field = field;
        }

        String reason() {
            return reason;
        }

        String field() {
            return field;
        }
    }
}
