package com.meowscope.server.common.error;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.meowscope.server.common.logging.RequestIdFilter;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.springframework.http.HttpStatusCode;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

class ApiExceptionHandlerTest {

    @RestController
    static class SampleController {
        @GetMapping("/conflict")
        void conflict() {
            throw new ApiException(ErrorCode.CONFLICT);
        }

        @GetMapping("/boom")
        void boom() {
            throw new IllegalStateException("内部の情報 password=secret");
        }
    }

    private final MockMvc mvc = MockMvcBuilders.standaloneSetup(new SampleController())
            .setControllerAdvice(new ApiExceptionHandler())
            .addFilters(new RequestIdFilter())
            .build();

    @Test
    @DisplayName("UT-ER-01 業務の例外は、その code と状態コードで返す")
    void 業務の例外() throws Exception {
        mvc.perform(get("/conflict").header("X-Request-Id", "r-1"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("CONFLICT"))
                .andExpect(jsonPath("$.title").value("すでに登録されています"))
                .andExpect(jsonPath("$.requestId").value("r-1"));
    }

    @Test
    @DisplayName("UT-ER-02 想定外の例外は 500 で、中身を本文に出さない")
    void 想定外の例外() throws Exception {
        String body = mvc.perform(get("/boom"))
                .andExpect(status().isInternalServerError())
                .andExpect(jsonPath("$.code").value("INTERNAL_ERROR"))
                .andExpect(jsonPath("$.requestId").isNotEmpty())
                .andReturn().getResponse().getContentAsString();
        assertThat(body).doesNotContain("secret").doesNotContain("IllegalStateException");
    }

    @Test
    @DisplayName("UT-ER-03 フレームワークのエラー（許可されていないメソッド）も同じ形で返す")
    void フレームワークのエラー() throws Exception {
        mvc.perform(post("/conflict"))
                .andExpect(status().isMethodNotAllowed())
                .andExpect(jsonPath("$.code").value("METHOD_NOT_ALLOWED"))
                .andExpect(jsonPath("$.detail").doesNotExist());
    }

    @ParameterizedTest(name = "UT-ER-04 状態コード {0} は {1}")
    @CsvSource({"400, VALIDATION_ERROR", "404, NOT_FOUND", "413, PAYLOAD_TOO_LARGE", "418, VALIDATION_ERROR",
        "500, INTERNAL_ERROR", "503, INTERNAL_ERROR"})
    void 状態コードとcode(int status, ErrorCode expected) {
        assertThat(ErrorCode.of(HttpStatusCode.valueOf(status))).isEqualTo(expected);
    }
}
