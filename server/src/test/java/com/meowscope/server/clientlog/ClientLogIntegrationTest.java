package com.meowscope.server.clientlog;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.meowscope.server.IntegrationTest;
import com.meowscope.server.TestUsers;
import com.meowscope.server.TestUsers.Registered;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.system.CapturedOutput;
import org.springframework.boot.test.system.OutputCaptureExtension;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import tools.jackson.databind.json.JsonMapper;

@IntegrationTest
@ExtendWith(OutputCaptureExtension.class)
class ClientLogIntegrationTest {

    @Autowired
    MockMvc mvc;

    @Autowired
    JsonMapper json;

    private static Map<String, Object> log(String status, String message) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("status", status);
        m.put("message", message);
        m.put("occurredAt", "2026-11-03T10:00:00Z");
        m.put("platform", "android");
        m.put("appVersion", "1.0.0");
        m.put("osVersion", "Android 15");
        m.put("requestId", "req-abc");
        return m;
    }

    private ResultActions send(Registered user, List<Map<String, Object>> logs) throws Exception {
        return mvc.perform(post("/api/v1/client-logs").header("Authorization", user.bearer())
                .contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("logs", logs))));
    }

    @Test
    @DisplayName("IT-CL-01 受け取ったログを logger.name client で、重大度と端末の属性と利用者の ID を付けて出す")
    void 出力(CapturedOutput output) throws Exception {
        Registered user = TestUsers.register(mvc);
        send(user, List.of(log("critical", "同期に失敗"), log("warning", "写真を送れない"))).andExpect(status().isNoContent());
        String out = output.getOut();
        assertThat(out).contains("\"name\":\"client\"").contains("\"status\":\"critical\"")
                .contains("\"status\":\"warning\"").contains("\"platform\":\"android\"")
                .contains("\"request_id\":\"req-abc\"").contains("\"usr\":{\"id\":\"" + user.id() + "\"}");
    }

    @Test
    @DisplayName("IT-CL-02 改行と制御文字を除き、メールアドレスを伏せる。許可していない属性は出さない")
    void 信頼しない(CapturedOutput output) throws Exception {
        Registered user = TestUsers.register(mvc);
        Map<String, Object> bad = log("error", "1行目\n{\"status\":\"alert\"}\u0007 haru@example.com");
        bad.put("usr.id", "なりすまし");
        send(user, List.of(bad)).andExpect(status().isNoContent());
        String line = output.getOut().lines().filter(l -> l.contains("1行目")).findFirst().orElseThrow();
        assertThat(line).contains("***@***").doesNotContain("haru@example.com").doesNotContain("なりすまし")
                .doesNotContain("\\n");
        assertThat(output.getOut()).doesNotContain("\"status\":\"alert\",\"message\"");
    }

    @Test
    @DisplayName("IT-CL-03 境界値：100件は可・101件は 400、本文 2000文字は可・2001文字は 400。alert と知らない値は 400")
    void 入力の検証() throws Exception {
        Registered user = TestUsers.register(mvc);
        List<Map<String, Object>> many = new ArrayList<>();
        for (int i = 0; i < 101; i++) {
            many.add(log("info", "x"));
        }
        send(user, many).andExpect(status().isBadRequest());
        send(user, many.subList(0, 100)).andExpect(status().isNoContent());
        send(user, List.of(log("info", "a".repeat(2000)))).andExpect(status().isNoContent());
        send(user, List.of(log("info", "a".repeat(2001)))).andExpect(status().isBadRequest());
        send(user, List.of(log("alert", "x"))).andExpect(status().isBadRequest());
        Map<String, Object> badPlatform = log("info", "x");
        badPlatform.put("platform", "ios");
        send(user, List.of(badPlatform)).andExpect(status().isBadRequest());
        mvc.perform(post("/api/v1/client-logs").contentType(MediaType.APPLICATION_JSON).content("{\"logs\":[]}"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("IT-CL-04 回数制限：1時間に60回までで、61回目は 429（境界値）。他の人は数えない")
    void 回数制限() throws Exception {
        Registered user = TestUsers.register(mvc);
        for (int i = 0; i < 60; i++) {
            send(user, List.of()).andExpect(status().isNoContent());
        }
        send(user, List.of()).andExpect(status().isTooManyRequests());
        send(TestUsers.register(mvc), List.of()).andExpect(status().isNoContent());
    }
}
