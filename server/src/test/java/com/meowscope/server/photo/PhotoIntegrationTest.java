package com.meowscope.server.photo;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.meowscope.server.IntegrationTest;
import com.meowscope.server.TestUsers;
import com.meowscope.server.TestUsers.Registered;
import java.util.Arrays;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import tools.jackson.databind.json.JsonMapper;

@IntegrationTest
class PhotoIntegrationTest {

    /** JPEG の先頭の印だけを持つ、テスト用のデータ。 */
    static final byte[] JPEG = {(byte) 0xFF, (byte) 0xD8, (byte) 0xFF, (byte) 0xE0, 1, 2, 3};

    @Autowired
    MockMvc mvc;

    @Autowired
    JdbcClient jdbc;

    @Autowired
    JsonMapper json;

    Registered haru;
    UUID recordId;

    @BeforeEach
    void setUp() throws Exception {
        haru = TestUsers.register(mvc);
        UUID household = UUID.randomUUID();
        UUID type = UUID.randomUUID();
        mvc.perform(post("/api/v1/households").header("Authorization", haru.bearer())
                .contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("id", household, "name", "みけ家", "recordTypes", List.of(
                        Map.of("id", type, "name", "ご飯", "kind", "food", "sortOrder", 0))))))
                .andExpect(status().isCreated());
        UUID cat = UUID.randomUUID();
        recordId = UUID.randomUUID();
        sync(haru, List.of(
                change("cats", cat, Map.of("householdId", household.toString(), "name", "ミケ", "status", "active"),
                        null),
                change("records", recordId, Map.of("catId", cat.toString(), "recordTypeId", type.toString(),
                        "recordedAt", "2026-11-03T08:00:00Z", "authorName", "はる"), null)));
        this.household = household;
    }

    UUID household;

    private static Map<String, Object> change(String table, UUID id, Map<String, Object> data, String deletedAt) {
        Map<String, Object> c = new LinkedHashMap<>();
        c.put("table", table);
        c.put("id", id);
        c.put("updatedAt", "2026-11-03T00:00:00Z");
        c.put("deletedAt", deletedAt);
        c.put("data", data);
        return c;
    }

    @SuppressWarnings("unchecked")
    private static Map<String, Object> data(Map<String, Object> change) {
        return (Map<String, Object>) change.get("data");
    }

    private Map<String, Object> photoData(int sort) {
        return Map.of("recordId", recordId.toString(), "sortOrder", sort);
    }

    @SuppressWarnings("unchecked")
    private List<String> sync(Registered user, List<Map<String, Object>> changes) throws Exception {
        String body = mvc.perform(post("/api/v1/sync").header("Authorization", user.bearer())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("lastSeq", 0, "changes", changes))))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        Map<String, Object> map = json.readValue(body, Map.class);
        return ((List<Map<String, Object>>) map.get("results")).stream().map(r -> (String) r.get("status")).toList();
    }

    @SuppressWarnings("unchecked")
    private List<Map<String, Object>> pulledPhotos(Registered user) throws Exception {
        String body = mvc.perform(post("/api/v1/sync").header("Authorization", user.bearer())
                        .contentType(MediaType.APPLICATION_JSON).content("{\"lastSeq\":0,\"changes\":[]}"))
                .andReturn().getResponse().getContentAsString();
        Map<String, Object> map = json.readValue(body, Map.class);
        return ((List<Map<String, Object>>) map.get("changes")).stream()
                .filter(c -> c.get("table").equals("record_photos")).toList();
    }

    private ResultActions upload(Registered user, UUID photoId, byte[] bytes, MediaType type) throws Exception {
        return mvc.perform(put("/api/v1/photos/" + photoId).header("Authorization", user.bearer())
                .contentType(type).content(bytes));
    }

    private UUID addPhoto(int sort) throws Exception {
        UUID id = UUID.randomUUID();
        assertThat(sync(haru, List.of(change("record_photos", id, photoData(sort), null))))
                .containsExactly("applied");
        return id;
    }

    @Test
    @DisplayName("IT-PH-01 写真の情報を同期してから送ると 204。取得すると同じ画像で、相手には送れたことが届く")
    void 送信と取得() throws Exception {
        Registered natsu = TestUsers.register(mvc);
        jdbc.sql("INSERT INTO household_members (id, household_id, user_id) VALUES (gen_random_uuid(), :h, :u)")
                .param("h", household).param("u", natsu.id()).update();
        UUID photo = addPhoto(1);
        assertThat(pulledPhotos(natsu)).singleElement()
                .satisfies(c -> assertThat(((Map<?, ?>) c.get("data")).get("uploaded")).isEqualTo(false));

        upload(haru, photo, JPEG, MediaType.IMAGE_JPEG).andExpect(status().isNoContent());

        mvc.perform(get("/api/v1/photos/" + photo).header("Authorization", natsu.bearer()))
                .andExpect(status().isOk())
                .andExpect(header().string("Content-Type", MediaType.IMAGE_JPEG_VALUE))
                .andExpect(content().bytes(JPEG));
        assertThat(pulledPhotos(natsu)).singleElement().satisfies(c -> assertThat(data(c))
                .containsEntry("uploaded", true).containsEntry("sizeBytes", JPEG.length));
        // 送り直しても同じ結果
        upload(haru, photo, JPEG, MediaType.IMAGE_JPEG).andExpect(status().isNoContent());
    }

    @Test
    @DisplayName("IT-PH-02 1つの記録に3枚まで。4枚目は rejected。何枚目かは 1〜3 だけ（境界値 0・1・3・4）")
    void 三枚まで() throws Exception {
        assertThat(sync(haru, List.of(change("record_photos", UUID.randomUUID(), photoData(0), null),
                change("record_photos", UUID.randomUUID(), photoData(4), null)))).containsOnly("rejected");
        addPhoto(1);
        addPhoto(2);
        UUID third = addPhoto(3);
        assertThat(sync(haru, List.of(change("record_photos", UUID.randomUUID(), photoData(3), null))))
                .containsExactly("rejected");
        // 3枚目を消すと、また付けられる
        assertThat(sync(haru, List.of(change("record_photos", third, photoData(3), "2026-11-03T09:00:00Z"))))
                .containsExactly("applied");
        addPhoto(3);
    }

    @Test
    @DisplayName("IT-PH-03 容量の境界値：5MB ちょうどは可、1バイト超えると 413。画像でない内容と形式は 415")
    void 容量と形式() throws Exception {
        UUID photo = addPhoto(1);
        byte[] max = Arrays.copyOf(JPEG, PhotoService.MAX_BYTES);
        upload(haru, photo, max, MediaType.IMAGE_JPEG).andExpect(status().isNoContent());
        byte[] over = Arrays.copyOf(JPEG, PhotoService.MAX_BYTES + 1);
        upload(haru, photo, over, MediaType.IMAGE_JPEG).andExpect(status().isPayloadTooLarge())
                .andExpect(jsonPath("$.code").value("PAYLOAD_TOO_LARGE"));
        upload(haru, photo, "<html>".getBytes(), MediaType.IMAGE_JPEG).andExpect(status().isUnsupportedMediaType());
        upload(haru, photo, JPEG, MediaType.TEXT_PLAIN).andExpect(status().isUnsupportedMediaType())
                .andExpect(jsonPath("$.code").value("UNSUPPORTED_MEDIA_TYPE"));
        byte[] png = {(byte) 0x89, 'P', 'N', 'G', 0x0D, 0x0A, 0x1A, 0x0A};
        upload(haru, photo, png, MediaType.IMAGE_PNG).andExpect(status().isNoContent());
        mvc.perform(get("/api/v1/photos/" + photo).header("Authorization", haru.bearer()))
                .andExpect(header().string("Content-Type", MediaType.IMAGE_PNG_VALUE));
    }

    @Test
    @DisplayName("IT-PH-04 権限：他のおうちの人は送信も取得も 404。ない写真・まだ送っていない写真の取得も 404")
    void 権限() throws Exception {
        UUID photo = addPhoto(1);
        mvc.perform(get("/api/v1/photos/" + photo).header("Authorization", haru.bearer()))
                .andExpect(status().isNotFound());
        upload(haru, photo, JPEG, MediaType.IMAGE_JPEG).andExpect(status().isNoContent());

        Registered other = TestUsers.register(mvc);
        upload(other, photo, JPEG, MediaType.IMAGE_JPEG).andExpect(status().isNotFound());
        mvc.perform(get("/api/v1/photos/" + photo).header("Authorization", other.bearer()))
                .andExpect(status().isNotFound());
        upload(haru, UUID.randomUUID(), JPEG, MediaType.IMAGE_JPEG).andExpect(status().isNotFound());
        mvc.perform(get("/api/v1/photos/" + photo)).andExpect(status().isUnauthorized());
        // 他のおうちの記録に写真の情報を付けることもできない
        assertThat(sync(other, List.of(change("record_photos", UUID.randomUUID(), photoData(1), null))))
                .containsExactly("rejected");
    }

    @Test
    @DisplayName("IT-PH-05 写真を消すと、サーバーの画像のファイルも消え、取得は 404")
    void 削除() throws Exception {
        UUID photo = addPhoto(1);
        upload(haru, photo, JPEG, MediaType.IMAGE_JPEG).andExpect(status().isNoContent());
        String path = jdbc.sql("SELECT file_path FROM record_photos WHERE id = :id").param("id", photo)
                .query(String.class).single();
        java.nio.file.Path file = java.nio.file.Path.of(System.getProperty("java.io.tmpdir"), "meowscope-test-photos",
                path);
        assertThat(file).exists();

        sync(haru, List.of(change("record_photos", photo, photoData(1), "2026-11-03T09:00:00Z")));

        assertThat(file).doesNotExist();
        mvc.perform(get("/api/v1/photos/" + photo).header("Authorization", haru.bearer()))
                .andExpect(status().isNotFound());
    }

    @Autowired
    PhotoStorage storage;

    @Autowired
    org.springframework.transaction.PlatformTransactionManager transactionManager;

    @Test
    @DisplayName("IT-PH-06 ファイルは DB の確定の後に消す：取り消したら残し、確定したら消す。トランザクションの外ではすぐ消す")
    void 確定の後に消す() throws Exception {
        var tx = new org.springframework.transaction.support.TransactionTemplate(transactionManager);
        String path = storage.saveAt("delete-test/" + UUID.randomUUID(), new byte[] {1});

        tx.executeWithoutResult(status -> {
            storage.delete(path);
            assertThat(exists(path)).isTrue();
            status.setRollbackOnly();
        });
        assertThat(exists(path)).isTrue();

        tx.executeWithoutResult(status -> {
            storage.delete(path);
            assertThat(exists(path)).isTrue();
        });
        assertThat(exists(path)).isFalse();

        String outside = storage.saveAt("delete-test/" + UUID.randomUUID(), new byte[] {2});
        storage.delete(outside);
        assertThat(exists(outside)).isFalse();
    }

    private boolean exists(String path) {
        try {
            storage.load(path);
            return true;
        } catch (java.io.IOException e) {
            return false;
        }
    }
}
