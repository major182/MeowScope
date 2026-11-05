package com.meowscope.server.auth;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.UUID;
import java.util.random.RandomGenerator;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class PasswordResetCodeTest {

    /** 決めた値を返す乱数。 */
    private static RandomGenerator fixed(int value) {
        return new RandomGenerator() {
            @Override
            public long nextLong() {
                return value;
            }

            @Override
            public int nextInt(int bound) {
                return value;
            }
        };
    }

    @Test
    @DisplayName("UT-PR-06 境界値：確認コードは先頭の 0 も含めて6桁（0 は 000000、999999 はそのまま）")
    void コードの形() {
        assertThat(PasswordResetService.newCode(fixed(0))).isEqualTo("000000");
        assertThat(PasswordResetService.newCode(fixed(42))).isEqualTo("000042");
        assertThat(PasswordResetService.newCode(fixed(999_999))).isEqualTo("999999");
    }

    @Test
    @DisplayName("UT-PR-07 コードのハッシュ：同じコードでも人ごとに違い、同じ人と同じコードなら同じ。コードそのものは含まない")
    void ハッシュ() {
        UUID a = UUID.randomUUID();
        UUID b = UUID.randomUUID();
        String hash = PasswordResetService.hash(a, "123456");
        assertThat(hash).isEqualTo(PasswordResetService.hash(a, "123456")).hasSize(64).doesNotContain("123456");
        assertThat(hash).isNotEqualTo(PasswordResetService.hash(b, "123456"))
                .isNotEqualTo(PasswordResetService.hash(a, "123457"));
    }
}
