package com.meowscope.server.release;

import static org.assertj.core.api.Assertions.assertThat;

import com.meowscope.server.release.ReleaseService.Release;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class ReleaseUnitTest {

    static final String SHA = "0123456789abcdef".repeat(4);

    @Test
    @DisplayName("UT-UP-01 版の情報の値の確かめ：ビルド番号・SHA-256・容量の境界値")
    void 値の確かめ() {
        assertThat(ReleaseService.valid(new Release("1.0.1", 1, SHA, 1))).isTrue();
        assertThat(ReleaseService.valid(new Release("1.0.1", 0, SHA, 1))).isFalse();
        assertThat(ReleaseService.valid(new Release("1.0.1", 1, SHA, 0))).isFalse();
        assertThat(ReleaseService.valid(new Release("1.0.1", 1, SHA.substring(1), 1))).isFalse();
        assertThat(ReleaseService.valid(new Release("1.0.1", 1, SHA + "0", 1))).isFalse();
        assertThat(ReleaseService.valid(new Release("1.0.1", 1, SHA.toUpperCase(), 1))).isFalse();
        assertThat(ReleaseService.valid(new Release("1.0.1", 1, null, 1))).isFalse();
        assertThat(ReleaseService.valid(new Release(" ", 1, SHA, 1))).isFalse();
        assertThat(ReleaseService.valid(new Release(null, 1, SHA, 1))).isFalse();
    }
}
