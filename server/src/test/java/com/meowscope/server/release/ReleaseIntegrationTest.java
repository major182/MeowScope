package com.meowscope.server.release;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.meowscope.server.IntegrationTest;
import com.meowscope.server.TestUsers;
import com.meowscope.server.TestUsers.Registered;
import java.nio.file.Files;
import java.nio.file.Path;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.util.FileSystemUtils;

@IntegrationTest
class ReleaseIntegrationTest {

    static final String SHA = "a".repeat(64);
    static final byte[] APK = {1, 2, 3, 4, 5};

    @Autowired
    MockMvc mvc;

    @Value("${meowscope.releases.dir}")
    Path root;

    Registered haru;

    @BeforeEach
    void setUp() throws Exception {
        FileSystemUtils.deleteRecursively(root);
        haru = TestUsers.register(mvc);
    }

    void place(String platform, String fileName, String json, byte[] bytes) throws Exception {
        Path dir = Files.createDirectories(root.resolve(platform));
        Files.writeString(dir.resolve("release.json"), json);
        if (bytes != null) {
            Files.write(dir.resolve(fileName), bytes);
        }
    }

    static String info(int build) {
        return """
                {"version": "1.0.1", "buildNumber": %d, "sha256": "%s", "sizeBytes": 5}""".formatted(build, SHA);
    }

    @Test
    @DisplayName("IT-UP-01 置いた版の情報を返し、ファイルはそのまま octet-stream で返す")
    void 版の情報とファイル() throws Exception {
        place("android", "meowscope.apk", info(2), APK);
        mvc.perform(get("/api/v1/app-releases/android/latest").header("Authorization", haru.bearer()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.version").value("1.0.1"))
                .andExpect(jsonPath("$.buildNumber").value(2))
                .andExpect(jsonPath("$.sha256").value(SHA))
                .andExpect(jsonPath("$.sizeBytes").value(5));
        mvc.perform(get("/api/v1/app-releases/android/file").header("Authorization", haru.bearer()))
                .andExpect(status().isOk())
                .andExpect(header().string("Content-Type", MediaType.APPLICATION_OCTET_STREAM_VALUE))
                .andExpect(content().bytes(APK));
    }

    @Test
    @DisplayName("IT-UP-02 Windows は Windows のフォルダーを読み、Android の版と混ざらない")
    void 端末ごとに分かれる() throws Exception {
        place("windows", "meowscope-setup.exe", info(7), APK);
        mvc.perform(get("/api/v1/app-releases/windows/latest").header("Authorization", haru.bearer()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.buildNumber").value(7));
        mvc.perform(get("/api/v1/app-releases/android/latest").header("Authorization", haru.bearer()))
                .andExpect(status().isNotFound());
    }

    @Test
    @DisplayName("IT-UP-03 置いていない・ファイルがない・知らない platform は 404")
    void ないときは404() throws Exception {
        mvc.perform(get("/api/v1/app-releases/android/latest").header("Authorization", haru.bearer()))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("NOT_FOUND"));
        mvc.perform(get("/api/v1/app-releases/android/file").header("Authorization", haru.bearer()))
                .andExpect(status().isNotFound());
        place("android", "meowscope.apk", info(2), null);
        mvc.perform(get("/api/v1/app-releases/android/latest").header("Authorization", haru.bearer()))
                .andExpect(status().isNotFound());
        mvc.perform(get("/api/v1/app-releases/ios/latest").header("Authorization", haru.bearer()))
                .andExpect(status().isNotFound());
        mvc.perform(get("/api/v1/app-releases/..%2Fandroid/file").header("Authorization", haru.bearer()))
                .andExpect(status().is4xxClientError());
    }

    @Test
    @DisplayName("IT-UP-04 認証なしは 401")
    void 認証なし() throws Exception {
        place("android", "meowscope.apk", info(2), APK);
        mvc.perform(get("/api/v1/app-releases/android/latest")).andExpect(status().isUnauthorized());
        mvc.perform(get("/api/v1/app-releases/android/file")).andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("IT-UP-05 版の情報が壊れている・値が正しくないときは 500（置き方の誤り）")
    void 壊れた版の情報() throws Exception {
        place("android", "meowscope.apk", "{not json", APK);
        mvc.perform(get("/api/v1/app-releases/android/latest").header("Authorization", haru.bearer()))
                .andExpect(status().isInternalServerError());
        place("android", "meowscope.apk", info(0), APK);
        mvc.perform(get("/api/v1/app-releases/android/latest").header("Authorization", haru.bearer()))
                .andExpect(status().isInternalServerError());
    }
}
