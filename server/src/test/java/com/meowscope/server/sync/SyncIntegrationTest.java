package com.meowscope.server.sync;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.meowscope.server.IntegrationTest;
import com.meowscope.server.TestUsers;
import com.meowscope.server.TestUsers.Registered;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.system.CapturedOutput;
import org.springframework.boot.test.system.OutputCaptureExtension;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
import tools.jackson.databind.json.JsonMapper;

@IntegrationTest
@ExtendWith(OutputCaptureExtension.class)
class SyncIntegrationTest {

    @Autowired
    MockMvc mvc;

    @Autowired
    JdbcClient jdbc;

    @Autowired
    JsonMapper json;

    Registered haru;
    UUID household;
    UUID food;

    @BeforeEach
    void setUp() throws Exception {
        haru = TestUsers.register(mvc);
        household = UUID.randomUUID();
        food = UUID.randomUUID();
        createHousehold(haru, household, food).andExpect(status().isCreated());
    }

    private ResultActions createHousehold(Registered user, UUID id, UUID typeId) throws Exception {
        String body = json.writeValueAsString(Map.of("id", id, "name", "みけ家", "recordTypes", List.of(
                Map.of("id", typeId, "name", "ご飯", "icon", "food", "kind", "food", "sortOrder", 0))));
        return mvc.perform(post("/api/v1/households").header("Authorization", user.bearer())
                .contentType(MediaType.APPLICATION_JSON).content(body));
    }

    /** 同じおうちに加える（招待の実装までは、テストの側で DB に直接入れる）。 */
    private void join(Registered user, UUID householdId) {
        jdbc.sql("INSERT INTO household_members (id, household_id, user_id) VALUES (gen_random_uuid(), :h, :u)")
                .param("h", householdId).param("u", user.id()).update();
    }

    private static Map<String, Object> change(String table, UUID id, Map<String, Object> data) {
        return change(table, id, data, null);
    }

    private static Map<String, Object> change(String table, UUID id, Map<String, Object> data, String deletedAt) {
        Map<String, Object> c = new LinkedHashMap<>();
        c.put("table", table);
        c.put("id", id);
        c.put("updatedAt", "2026-11-03T00:00:00Z");
        c.put("deletedAt", deletedAt);
        c.put("data", data);
        return c;
    }

    private Map<String, Object> cat(String name) {
        return Map.of("householdId", household.toString(), "name", name, "status", "active");
    }

    private Map<String, Object> record(UUID catId, String memo) {
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("catId", catId.toString());
        data.put("recordTypeId", food.toString());
        data.put("recordedAt", "2026-11-03T08:00:00Z");
        data.put("authorName", "はる");
        data.put("level", "normal");
        data.put("detail", Map.of("note", "x"));
        data.put("memo", memo);
        return data;
    }

    private ResultActions sync(Registered user, long lastSeq, List<Map<String, Object>> changes) throws Exception {
        String body = json.writeValueAsString(Map.of("lastSeq", lastSeq, "changes", changes));
        return mvc.perform(post("/api/v1/sync").header("Authorization", user.bearer())
                .contentType(MediaType.APPLICATION_JSON).content(body));
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> syncBody(Registered user, long lastSeq, List<Map<String, Object>> changes)
            throws Exception {
        String body = sync(user, lastSeq, changes).andExpect(status().isOk()).andReturn().getResponse()
                .getContentAsString();
        return json.readValue(body, Map.class);
    }

    @SuppressWarnings("unchecked")
    private static List<String> statuses(Map<String, Object> body) {
        return ((List<Map<String, Object>>) body.get("results")).stream().map(r -> (String) r.get("status")).toList();
    }

    @SuppressWarnings("unchecked")
    private static List<Map<String, Object>> changes(Map<String, Object> body, String table) {
        return ((List<Map<String, Object>>) body.get("changes")).stream()
                .filter(c -> c.get("table").equals(table)).toList();
    }

    /** 結果ごとの「理由:項目」。理由がなければ null。 */
    @SuppressWarnings("unchecked")
    private static List<String> reasons(Map<String, Object> body) {
        return ((List<Map<String, Object>>) body.get("results")).stream().map(r -> r.get("reason") == null ? null
                : r.get("field") == null ? (String) r.get("reason") : r.get("reason") + ":" + r.get("field")).toList();
    }

    private static long nextSeq(Map<String, Object> body) {
        return ((Number) body.get("nextSeq")).longValue();
    }

    @Test
    @DisplayName("IT-SY-01 おうちの作成：おうち・作った人のメンバー・記録項目を ID ごと作る。送り直しは 200、他の人の ID は 404")
    void おうちの作成() throws Exception {
        assertThat(jdbc.sql("SELECT count(*) FROM household_members WHERE household_id = :h AND user_id = :u")
                .param("h", household).param("u", haru.id()).query(Long.class).single()).isEqualTo(1);
        assertThat(jdbc.sql("SELECT name FROM record_types WHERE id = :id").param("id", food)
                .query(String.class).single()).isEqualTo("ご飯");

        createHousehold(haru, household, food).andExpect(status().isOk());

        Registered other = TestUsers.register(mvc);
        createHousehold(other, household, UUID.randomUUID()).andExpect(status().isNotFound());
        mvc.perform(post("/api/v1/households").header("Authorization", other.bearer())
                        .contentType(MediaType.APPLICATION_JSON).content("{\"id\":null,\"name\":\"\"}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    @DisplayName("IT-SY-02 送った猫と記録は applied になり、同じおうちの相手が受け取る。投稿者の ID はトークンのユーザー")
    void 共有() throws Exception {
        Registered natsu = TestUsers.register(mvc, TestUsers.uniqueEmail(), "なつ");
        join(natsu, household);
        UUID catId = UUID.randomUUID();
        UUID recordId = UUID.randomUUID();
        Map<String, Object> sent = syncBody(haru, 0, List.of(
                change("records", recordId, record(catId, "よく食べた")),
                change("cats", catId, cat("ミケ"))));
        // 記録を先に送っても、猫を先に反映する
        assertThat(statuses(sent)).containsExactly("applied", "applied");

        Map<String, Object> received = syncBody(natsu, 0, List.of());
        assertThat(changes(received, "cats")).singleElement()
                .satisfies(c -> assertThat(c).containsEntry("id", catId.toString()));
        @SuppressWarnings("unchecked")
        Map<String, Object> data = (Map<String, Object>) changes(received, "records").getFirst().get("data");
        assertThat(data).containsEntry("memo", "よく食べた").containsEntry("authorId", haru.id().toString())
                .containsEntry("detail", Map.of("note", "x"));
        assertThat(changes(received, "households")).hasSize(1);
        assertThat(changes(received, "household_members")).hasSize(2);
        assertThat(changes(received, "users").stream().map(c -> (String) ((Map<?, ?>) c.get("data")).get("displayName")).toList())
                .contains("はる", "なつ");
        assertThat(received.toString()).doesNotContain(haru.email()).doesNotContain("password");
    }

    @Test
    @DisplayName("IT-SY-03 送り直し：同じ内容は ignored で、通し番号は進まない")
    void 送り直し() throws Exception {
        UUID catId = UUID.randomUUID();
        List<Map<String, Object>> changes = List.of(change("cats", catId, cat("ミケ")));
        syncBody(haru, 0, changes);
        long seq = catSeq(catId);
        Map<String, Object> again = syncBody(haru, 0, changes);
        assertThat(statuses(again)).containsExactly("ignored");
        assertThat(catSeq(catId)).isEqualTo(seq);
    }

    private long catSeq(UUID id) {
        return jdbc.sql("SELECT server_seq FROM cats WHERE id = :id").param("id", id).query(Long.class).single();
    }

    @Test
    @DisplayName("IT-SY-04 競合：後から受け取った変更が残る（更新日時が古くても、BR-10）")
    void 競合() throws Exception {
        Registered natsu = TestUsers.register(mvc);
        join(natsu, household);
        UUID catId = UUID.randomUUID();
        syncBody(haru, 0, List.of(change("cats", catId, cat("ミケ"))));
        Map<String, Object> later = change("cats", catId, cat("タマ"));
        later.put("updatedAt", "2020-01-01T00:00:00Z");
        syncBody(natsu, 0, List.of(change("cats", catId, cat("クロ"))));
        syncBody(haru, 0, List.of(later));
        assertThat(jdbc.sql("SELECT name FROM cats WHERE id = :id").param("id", catId).query(String.class)
                .single()).isEqualTo("タマ");
    }

    @Test
    @DisplayName("IT-SY-05 削除も更新として届く（BR-11）")
    void 削除() throws Exception {
        Registered natsu = TestUsers.register(mvc);
        join(natsu, household);
        UUID catId = UUID.randomUUID();
        UUID recordId = UUID.randomUUID();
        syncBody(haru, 0, List.of(change("cats", catId, cat("ミケ")),
                change("records", recordId, record(catId, null))));
        long seq = nextSeq(syncBody(natsu, 0, List.of()));

        syncBody(haru, 0, List.of(change("records", recordId, record(catId, null), "2026-11-03T09:00:00Z")));

        Map<String, Object> received = syncBody(natsu, seq, List.of());
        assertThat(changes(received, "records")).singleElement()
                .satisfies(c -> assertThat(c.get("deletedAt")).isEqualTo("2026-11-03T09:00:00Z"));
    }

    @Test
    @DisplayName("IT-SY-06 権限：他のおうちへの変更は rejected。他のおうちのデータは受け取らない（AC-07）")
    void 他のおうち() throws Exception {
        UUID catId = UUID.randomUUID();
        syncBody(haru, 0, List.of(change("cats", catId, cat("ミケ"))));
        Registered other = TestUsers.register(mvc);

        Map<String, Object> body = syncBody(other, 0, List.of(
                change("cats", UUID.randomUUID(), cat("ねらい")),
                change("cats", catId, cat("上書き")),
                change("records", UUID.randomUUID(), record(catId, null)),
                change("households", household, Map.of("name", "乗っ取り"))));

        assertThat(statuses(body)).containsOnly("rejected");
        assertThat(changes(body, "cats")).isEmpty();
        assertThat(changes(body, "households")).isEmpty();
        assertThat(jdbc.sql("SELECT name FROM cats WHERE id = :id").param("id", catId).query(String.class).single())
                .isEqualTo("ミケ");
    }

    @Test
    @DisplayName("IT-SY-07 内容の誤りは、その変更だけ rejected にし、ほかは反映する。理由と項目を返す")
    void 内容の誤り() throws Exception {
        UUID catId = UUID.randomUUID();
        Map<String, Object> badLevel = record(catId, null);
        badLevel.put("level", "huge");
        Map<String, Object> badWeight = record(catId, null);
        badWeight.put("valueNumber", 1001);
        Map<String, Object> noName = new LinkedHashMap<>(cat("x"));
        noName.remove("name");
        Map<String, Object> badDate = new LinkedHashMap<>(cat("x"));
        badDate.put("birthDate", "きのう");
        Map<String, Object> body = syncBody(haru, 0, List.of(
                change("cats", catId, cat("ミケ")),
                change("records", UUID.randomUUID(), badLevel),
                change("records", UUID.randomUUID(), badWeight),
                change("cats", UUID.randomUUID(), noName),
                change("cats", UUID.randomUUID(), badDate),
                change("unknown", UUID.randomUUID(), Map.of()),
                change("records", UUID.randomUUID(), record(UUID.randomUUID(), null))));
        assertThat(statuses(body)).containsExactly("applied", "rejected", "rejected", "rejected", "rejected",
                "rejected", "rejected");
        // 端末が利用者に示せるよう、理由と項目の名前を返す。反映したものには返さない（Issue #83）
        assertThat(reasons(body)).containsExactly(null, "invalid:level", "invalid:valueNumber", "invalid:name",
                "invalid:birthDate", "unknown_table", "not_found:catId");
    }

    @Test
    @DisplayName("IT-SY-08 おうちの付け替えは受け付けない")
    void 付け替え() throws Exception {
        UUID other = UUID.randomUUID();
        createHousehold(haru, other, UUID.randomUUID()).andExpect(status().isCreated());
        UUID catId = UUID.randomUUID();
        syncBody(haru, 0, List.of(change("cats", catId, cat("ミケ"))));
        Map<String, Object> moved = new LinkedHashMap<>(cat("ミケ"));
        moved.put("householdId", other.toString());
        assertThat(statuses(syncBody(haru, 0, List.of(change("cats", catId, moved))))).containsExactly("rejected");
    }

    @Test
    @DisplayName("IT-SY-09 分割の境界値：503件は500件と3件に分けて返し（hasMore）、続きがなければ番号は変わらない")
    void 分割() throws Exception {
        UUID catId = UUID.randomUUID();
        syncBody(haru, 0, List.of(change("cats", catId, cat("ミケ"))));
        // 500件ずつしか送れないので、DB に直接入れる
        jdbc.sql("""
                INSERT INTO records (id, cat_id, record_type_id, recorded_at, author_name)
                SELECT gen_random_uuid(), :cat, :type, now(), 'はる' FROM generate_series(1, 497)
                """).param("cat", catId).param("type", food).update();
        // ここまでで おうち・メンバー・ユーザー・記録項目・設定・猫・記録497件 ＝ 503件
        Map<String, Object> first = syncBody(haru, 0, List.of());
        assertThat((List<?>) first.get("changes")).hasSize(500);
        assertThat(first.get("hasMore")).isEqualTo(true);
        Map<String, Object> second = syncBody(haru, nextSeq(first), List.of());
        assertThat((List<?>) second.get("changes")).hasSize(3);
        assertThat(second.get("hasMore")).isEqualTo(false);
        Map<String, Object> third = syncBody(haru, nextSeq(second), List.of());
        assertThat((List<?>) third.get("changes")).isEmpty();
        assertThat(nextSeq(third)).isEqualTo(nextSeq(second));
    }

    @Test
    @DisplayName("IT-SY-10 全件の取り直し：端末の番号がサーバーより先のとき、前回の後に別のおうちに加わったとき")
    void 全件の取り直し() throws Exception {
        assertThat(syncBody(haru, Long.MAX_VALUE / 2, List.of()).get("fullResyncRequired")).isEqualTo(true);

        long seq = nextSeq(syncBody(haru, 0, List.of()));
        assertThat(syncBody(haru, seq, List.of()).get("fullResyncRequired")).isEqualTo(false);
        Registered natsu = TestUsers.register(mvc);
        UUID other = UUID.randomUUID();
        createHousehold(natsu, other, UUID.randomUUID());
        join(haru, other);
        Map<String, Object> body = syncBody(haru, seq, List.of());
        assertThat(body.get("fullResyncRequired")).isEqualTo(true);
        assertThat(nextSeq(body)).isEqualTo(seq);
    }

    private Map<String, Object> button(UUID typeId, int sort) {
        return Map.of("recordTypeId", typeId.toString(), "sortOrder", sort);
    }

    @Test
    @DisplayName("IT-SY-15 ウィジェットのボタン：4つまで（境界値）。自分の分だけを受け取り、他の人・他のおうちの項目は rejected（BR-22）")
    void ウィジェットのボタン() throws Exception {
        List<UUID> ids = List.of(UUID.randomUUID(), UUID.randomUUID(), UUID.randomUUID(), UUID.randomUUID());
        List<Map<String, Object>> four = new ArrayList<>();
        for (int i = 0; i < 4; i++) {
            four.add(change("widget_buttons", ids.get(i), button(food, i)));
        }
        four.add(change("widget_buttons", UUID.randomUUID(), button(food, 3)));
        Map<String, Object> body = syncBody(haru, 0, four);
        assertThat(statuses(body)).containsExactly("applied", "applied", "applied", "applied", "rejected");
        assertThat(changes(body, "widget_buttons")).hasSize(4);

        // 並び順の変更と削除。削除で空いたら、また追加できる
        body = syncBody(haru, 0, List.of(
                change("widget_buttons", ids.get(0), button(food, 1)),
                change("widget_buttons", ids.get(1), button(food, 0), "2026-11-03T09:00:00Z"),
                change("widget_buttons", UUID.randomUUID(), button(food, 3)),
                change("widget_buttons", ids.get(2), button(food, 2))));
        assertThat(statuses(body)).containsExactly("applied", "applied", "applied", "ignored");

        // 同じおうちの別の人：はるのボタンは受け取らず、変えられない
        Registered aki = TestUsers.register(mvc);
        join(aki, household);
        body = syncBody(aki, 0, List.of(change("widget_buttons", ids.get(0), button(food, 0))));
        assertThat(statuses(body)).containsExactly("rejected");
        assertThat(changes(body, "widget_buttons")).isEmpty();

        // 自分の属さないおうちの記録項目と、ない記録項目は rejected
        Registered other = TestUsers.register(mvc);
        UUID otherFood = UUID.randomUUID();
        createHousehold(other, UUID.randomUUID(), otherFood).andExpect(status().isCreated());
        body = syncBody(haru, 0, List.of(
                change("widget_buttons", UUID.randomUUID(), button(otherFood, 0)),
                change("widget_buttons", UUID.randomUUID(), button(UUID.randomUUID(), 0)),
                change("widget_buttons", UUID.randomUUID(), button(food, 4))));
        assertThat(statuses(body)).containsOnly("rejected");
    }

    @Test
    @DisplayName("IT-SY-11 設定：自分の週の始まりを更新し、自分の分だけを受け取る。おうちの名前を変える")
    void 設定とおうちの名前() throws Exception {
        Map<String, Object> body = syncBody(haru, 0, List.of(
                change("user_settings", UUID.randomUUID(), Map.of("weekStart", "monday")),
                change("households", household, Map.of("name", "みけ家2")),
                change("households", UUID.randomUUID(), Map.of("name", "ない"))));
        assertThat(statuses(body)).containsExactly("applied", "applied", "rejected");
        assertThat(changes(body, "user_settings")).singleElement()
                .satisfies(c -> assertThat(((Map<?, ?>) c.get("data")).get("weekStart")).isEqualTo("monday"));
        assertThat(changes(body, "households")).singleElement()
                .satisfies(c -> assertThat(c.get("data")).isEqualTo(Map.of("name", "みけ家2")));
    }

    @Test
    @DisplayName("IT-SY-12 入力の検証：501件は 400、500件は可（境界値）。番号が負は 400。認証なしは 401")
    void 入力の検証() throws Exception {
        List<Map<String, Object>> many = new ArrayList<>();
        for (int i = 0; i < 501; i++) {
            many.add(change("user_settings", UUID.randomUUID(), Map.of("weekStart", "sunday")));
        }
        sync(haru, 0, many).andExpect(status().isBadRequest());
        sync(haru, 0, many.subList(0, 500)).andExpect(status().isOk());
        sync(haru, -1, List.of()).andExpect(status().isBadRequest());
        mvc.perform(post("/api/v1/sync").contentType(MediaType.APPLICATION_JSON).content("{}"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("IT-SY-13 抜けた人には、自分のメンバーの行の削除だけが届き、おうちのデータは届かない")
    void 抜けた人() throws Exception {
        Registered natsu = TestUsers.register(mvc);
        join(natsu, household);
        long seq = nextSeq(syncBody(natsu, 0, List.of()));
        jdbc.sql("""
                UPDATE household_members SET deleted_at = now(), server_seq = nextval('sync_seq')
                WHERE user_id = :u
                """).param("u", natsu.id()).update();
        syncBody(haru, 0, List.of(change("cats", UUID.randomUUID(), cat("ミケ"))));

        Map<String, Object> body = syncBody(natsu, seq, List.of());
        assertThat(changes(body, "household_members")).singleElement()
                .satisfies(c -> assertThat(c.get("deletedAt")).isNotNull());
        assertThat(changes(body, "cats")).isEmpty();
    }

    @Test
    @DisplayName("IT-SY-14 ログ：件数を info、受け付けなかった変更を warning で出し、記録の内容は出さない")
    void ログ(CapturedOutput output) throws Exception {
        UUID catId = UUID.randomUUID();
        Map<String, Object> bad = record(catId, "ひみつのメモ");
        bad.put("level", "huge");
        syncBody(haru, 0, List.of(change("cats", catId, cat("ミケ")), change("records", UUID.randomUUID(), bad)));
        assertThat(output.getOut())
                .contains("\"sync\":{\"received\":2,\"applied\":1,\"ignored\":0,\"rejected\":1")
                .contains("sync_rejected")
                .contains("\"status\":\"warning\"")
                .doesNotContain("ひみつのメモ")
                .doesNotContain("ミケ");
        mvc.perform(post("/api/v1/sync").header("Authorization", haru.bearer())
                        .contentType(MediaType.APPLICATION_JSON).content("{\"lastSeq\":0}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
    }

    @Autowired
    PlatformTransactionManager transactionManager;

    private long seqOfCat(UUID id) {
        return jdbc.sql("SELECT server_seq FROM cats WHERE id = :id").param("id", id).query(Long.class).single();
    }

    @Test
    @DisplayName("IT-SY-16 同時の変更：先に番号を取った変更が確定するまで、次の変更は番号を取れない。確定の順と番号の順が同じ（BR-10）")
    void 番号は確定の順() throws Exception {
        UUID first = UUID.randomUUID();
        UUID second = UUID.randomUUID();
        syncBody(haru, 0, List.of(change("cats", first, cat("ミケ")), change("cats", second, cat("タマ"))));
        TransactionTemplate tx = new TransactionTemplate(transactionManager);
        CountDownLatch updated = new CountDownLatch(1);
        CountDownLatch release = new CountDownLatch(1);

        // 1つ目：番号を進めたまま、確定を待たせる
        CompletableFuture<Void> a = CompletableFuture.runAsync(() -> tx.executeWithoutResult(s -> {
            jdbc.sql("UPDATE cats SET name = 'ミケ2', server_seq = nextval('sync_seq') WHERE id = :id")
                    .param("id", first).update();
            updated.countDown();
            try {
                release.await(10, TimeUnit.SECONDS);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        }));
        assertThat(updated.await(10, TimeUnit.SECONDS)).isTrue();
        // 2つ目：1つ目の確定まで待つ
        CompletableFuture<Void> b = CompletableFuture.runAsync(() -> tx.executeWithoutResult(s -> jdbc.sql(
                "UPDATE cats SET name = 'タマ2', server_seq = nextval('sync_seq') WHERE id = :id")
                .param("id", second).update()));
        Thread.sleep(500);
        assertThat(b).isNotDone();

        release.countDown();
        a.get(10, TimeUnit.SECONDS);
        b.get(10, TimeUnit.SECONDS);
        assertThat(seqOfCat(second)).isGreaterThan(seqOfCat(first));
    }

    @Test
    @DisplayName("IT-SY-17 同期の途中の変更：変更の確定を待ってから読む。最後のページの次の位置は、振った番号の最新")
    void 読むときは確定を待つ() throws Exception {
        UUID id = UUID.randomUUID();
        long start = ((Number) syncBody(haru, 0, List.of(change("cats", id, cat("ミケ")))).get("nextSeq")).longValue();
        TransactionTemplate tx = new TransactionTemplate(transactionManager);
        CountDownLatch updated = new CountDownLatch(1);
        CountDownLatch release = new CountDownLatch(1);
        CompletableFuture<Void> writer = CompletableFuture.runAsync(() -> tx.executeWithoutResult(s -> {
            jdbc.sql("UPDATE cats SET name = 'ミケ2', server_seq = nextval('sync_seq') WHERE id = :id")
                    .param("id", id).update();
            updated.countDown();
            try {
                release.await(10, TimeUnit.SECONDS);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        }));
        assertThat(updated.await(10, TimeUnit.SECONDS)).isTrue();

        CompletableFuture<Map<String, Object>> reading = CompletableFuture.supplyAsync(() -> {
            try {
                return syncBody(haru, start, List.of());
            } catch (Exception e) {
                throw new IllegalStateException(e);
            }
        });
        Thread.sleep(500);
        assertThat(reading).isNotDone();
        release.countDown();
        writer.get(10, TimeUnit.SECONDS);

        Map<String, Object> body = reading.get(10, TimeUnit.SECONDS);
        assertThat(changes(body, "cats")).extracting(c -> (Object) ((Map<?, ?>) c.get("data")).get("name"))
                .containsExactly("ミケ2");
        long latest = jdbc.sql("SELECT last_value FROM sync_seq").query(Long.class).single();
        assertThat(((Number) body.get("nextSeq")).longValue()).isEqualTo(latest);
    }

    @Test
    @DisplayName("IT-SY-18 記録項目がないときは not_found、ほかのおうちの項目のときは forbidden")
    void 記録項目の理由() throws Exception {
        UUID catId = UUID.randomUUID();
        Registered natsu = TestUsers.register(mvc);
        UUID otherType = UUID.randomUUID();
        createHousehold(natsu, UUID.randomUUID(), otherType).andExpect(status().isCreated());
        Map<String, Object> missing = record(catId, null);
        missing.put("recordTypeId", UUID.randomUUID().toString());
        Map<String, Object> others = record(catId, null);
        others.put("recordTypeId", otherType.toString());

        Map<String, Object> body = syncBody(haru, 0, List.of(change("cats", catId, cat("ミケ")),
                change("records", UUID.randomUUID(), missing), change("records", UUID.randomUUID(), others)));

        assertThat(reasons(body)).containsExactly(null, "not_found:recordTypeId", "forbidden:recordTypeId");
    }

    @Test
    @DisplayName("IT-SY-19 おうちの作成：記録項目の ID がほかのおうちの項目とぶつかったら 409 で、おうちも作らない")
    void 記録項目のIDの重複() throws Exception {
        Registered natsu = TestUsers.register(mvc);
        UUID other = UUID.randomUUID();
        createHousehold(natsu, other, food).andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("CONFLICT"));
        assertThat(jdbc.sql("SELECT count(*) FROM households WHERE id = :id").param("id", other).query(Long.class)
                .single()).isZero();
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> settingsOf(Map<String, Object> body) {
        return (Map<String, Object>) changes(body, "user_settings").getFirst().get("data");
    }

    @Test
    @DisplayName("IT-SY-20 通知の設定：記録忘れの時間・種類ごとのオン・オフ・判定方式を保存して返す。送らなかった項目は変えず、null の時間はオフ")
    void 通知の設定() throws Exception {
        Map<String, Object> all = new LinkedHashMap<>();
        all.put("weekStart", "sunday");
        all.put("reminderHours", 12);
        all.put("notifications", Map.of("family", false, "birthday", true));
        all.put("anomalyMethod", "threshold");
        syncBody(haru, 0, List.of(change("user_settings", UUID.randomUUID(), all)));
        Map<String, Object> saved = settingsOf(syncBody(haru, 0, List.of()));
        assertThat(saved).containsEntry("reminderHours", 12).containsEntry("anomalyMethod", "threshold")
                .containsEntry("notifications", Map.of("birthday", true, "family", false));

        // 古いアプリは週の始まりだけを送る。ほかの設定は消さない
        syncBody(haru, 0, List.of(change("user_settings", UUID.randomUUID(), Map.of("weekStart", "monday"))));
        assertThat(settingsOf(syncBody(haru, 0, List.of()))).containsEntry("weekStart", "monday")
                .containsEntry("reminderHours", 12).containsEntry("anomalyMethod", "threshold");

        // 記録忘れをオフにする（null）
        Map<String, Object> off = new LinkedHashMap<>();
        off.put("weekStart", "monday");
        off.put("reminderHours", null);
        syncBody(haru, 0, List.of(change("user_settings", UUID.randomUUID(), off)));
        assertThat(settingsOf(syncBody(haru, 0, List.of()))).containsEntry("reminderHours", null);
    }

    @Test
    @DisplayName("IT-SY-21 通知の設定の入力の検証：時間は 1〜48（境界値 0・49 は rejected）、知らない種類・真偽値でない値・知らない判定方式は rejected")
    void 通知の設定の検証() throws Exception {
        Map<String, Object> body = syncBody(haru, 0, List.of(
                change("user_settings", UUID.randomUUID(), Map.of("weekStart", "sunday", "reminderHours", 1)),
                change("user_settings", UUID.randomUUID(), Map.of("weekStart", "sunday", "reminderHours", 48)),
                change("user_settings", UUID.randomUUID(), Map.of("weekStart", "sunday", "reminderHours", 0)),
                change("user_settings", UUID.randomUUID(), Map.of("weekStart", "sunday", "reminderHours", 49)),
                change("user_settings", UUID.randomUUID(),
                        Map.of("weekStart", "sunday", "notifications", Map.of("unknown", true))),
                change("user_settings", UUID.randomUUID(),
                        Map.of("weekStart", "sunday", "notifications", Map.of("family", "yes"))),
                change("user_settings", UUID.randomUUID(), Map.of("weekStart", "sunday", "anomalyMethod", "ai"))));
        assertThat(reasons(body)).containsExactly(null, null, "invalid:reminderHours", "invalid:reminderHours",
                "invalid:notifications", "invalid:notifications", "invalid:anomalyMethod");
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> catData(Map<String, Object> body, UUID id) {
        return (Map<String, Object>) changes(body, "cats").stream().filter(c -> c.get("id").equals(id.toString()))
                .findFirst().orElseThrow().get("data");
    }

    @Test
    @DisplayName("IT-SY-22 しきい値：猫のしきい値を保存して返し、家族にも届く。送らなかったときは変えず、null で消す")
    void しきい値() throws Exception {
        UUID catId = UUID.randomUUID();
        Map<String, Object> withRule = new LinkedHashMap<>(cat("ミケ"));
        withRule.put("anomalyThresholds", Map.of("food", Map.of("min", 2, "max", 5), "weight", Map.of("percent", 8)));
        assertThat(statuses(syncBody(haru, 0, List.of(change("cats", catId, withRule))))).containsExactly("applied");
        assertThat(catData(syncBody(haru, 0, List.of()), catId).get("anomalyThresholds"))
                .isEqualTo(Map.of("food", Map.of("max", 5, "min", 2), "weight", Map.of("percent", 8)));

        // 古いアプリはしきい値を送らない。名前を変えても、しきい値は残る
        syncBody(haru, 0, List.of(change("cats", catId, cat("ミケ2"))));
        assertThat(catData(syncBody(haru, 0, List.of()), catId).get("anomalyThresholds")).isNotNull();

        Map<String, Object> cleared = new LinkedHashMap<>(cat("ミケ2"));
        cleared.put("anomalyThresholds", null);
        syncBody(haru, 0, List.of(change("cats", catId, cleared)));
        assertThat(catData(syncBody(haru, 0, List.of()), catId).get("anomalyThresholds")).isNull();
    }

    @Test
    @DisplayName("IT-SY-23 しきい値の入力の検証：回数は 0〜99（境界値 -1・100）で下限は上限以下、体重は 1〜50（0・51）、知らない種類・項目は rejected")
    void しきい値の検証() throws Exception {
        List<Map<String, Object>> rules = List.of(
                Map.of("food", Map.of("min", 0, "max", 99)),
                Map.of("weight", Map.of("percent", 1)),
                Map.of("weight", Map.of("percent", 50)),
                Map.of("food", Map.of("min", -1)),
                Map.of("food", Map.of("max", 100)),
                Map.of("food", Map.of("min", 3, "max", 2)),
                Map.of("weight", Map.of("percent", 0)),
                Map.of("weight", Map.of("percent", 51)),
                Map.of("medicine", Map.of("min", 1)),
                Map.of("food", Map.of("avg", 1)));
        List<Map<String, Object>> sent = new ArrayList<>();
        for (Map<String, Object> rule : rules) {
            Map<String, Object> data = new LinkedHashMap<>(cat("ミケ"));
            data.put("anomalyThresholds", rule);
            sent.add(change("cats", UUID.randomUUID(), data));
        }
        Map<String, Object> body = syncBody(haru, 0, sent);
        assertThat(reasons(body)).containsExactly(null, null, null, "invalid:anomalyThresholds",
                "invalid:anomalyThresholds", "invalid:anomalyThresholds", "invalid:anomalyThresholds",
                "invalid:anomalyThresholds", "invalid:anomalyThresholds", "invalid:anomalyThresholds");
    }

    private Map<String, Object> medication(UUID catId, String name, String dose, String time) {
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("householdId", household.toString());
        data.put("catId", catId.toString());
        data.put("name", name);
        data.put("dose", dose);
        data.put("timeOfDay", time);
        return data;
    }

    @SuppressWarnings("unchecked")
    private static Map<String, Object> dataOf(Map<String, Object> body, String table, UUID id) {
        return changes(body, table).stream().filter(c -> c.get("id").equals(id.toString())).findFirst()
                .map(c -> (Map<String, Object>) c.get("data")).orElseThrow();
    }

    @Test
    @DisplayName("IT-SY-24 お薬の予定：保存して家族にも届く。オン・オフを送らなければオン。変更と削除も届く（F-MD-02）")
    void お薬の予定() throws Exception {
        Registered natsu = TestUsers.register(mvc, TestUsers.uniqueEmail(), "なつ");
        join(natsu, household);
        UUID catId = UUID.randomUUID();
        UUID id = UUID.randomUUID();
        assertThat(statuses(syncBody(haru, 0, List.of(change("cats", catId, cat("ミケ")),
                change("medication_schedules", id, medication(catId, "○○錠", "1錠", "08:00"))))))
                .containsExactly("applied", "applied");

        assertThat(dataOf(syncBody(natsu, 0, List.of()), "medication_schedules", id))
                .containsEntry("householdId", household.toString()).containsEntry("catId", catId.toString())
                .containsEntry("name", "○○錠").containsEntry("dose", "1錠").containsEntry("timeOfDay", "08:00")
                .containsEntry("enabled", true);

        Map<String, Object> off = medication(catId, "○○錠", null, "20:00");
        off.put("enabled", false);
        assertThat(statuses(syncBody(natsu, 0, List.of(change("medication_schedules", id, off)))))
                .containsExactly("applied");
        Map<String, Object> changed = dataOf(syncBody(haru, 0, List.of()), "medication_schedules", id);
        assertThat(changed).containsEntry("timeOfDay", "20:00").containsEntry("enabled", false);
        assertThat(changed.get("dose")).isNull();

        // 同じ内容の送り直しは ignored
        assertThat(statuses(syncBody(natsu, 0, List.of(change("medication_schedules", id, off)))))
                .containsExactly("ignored");

        syncBody(haru, 0, List.of(change("medication_schedules", id, off, "2026-11-07T00:00:00Z")));
        assertThat(changes(syncBody(natsu, 0, List.of()), "medication_schedules").getFirst().get("deletedAt"))
                .isNotNull();
    }

    @Test
    @DisplayName("IT-SY-25 お薬の予定の入力の検証：名前は必須・20文字まで（境界値 20・21）、量は20文字まで、時刻は 00:00〜23:59（24:00・8:00・08:60 は rejected）")
    void お薬の予定の検証() throws Exception {
        UUID catId = UUID.randomUUID();
        syncBody(haru, 0, List.of(change("cats", catId, cat("ミケ"))));
        String twenty = "あ".repeat(20);
        List<Map<String, Object>> data = List.of(
                medication(catId, twenty, twenty, "00:00"),
                medication(catId, "薬", null, "23:59"),
                medication(catId, twenty + "あ", null, "08:00"),
                medication(catId, " ", null, "08:00"),
                medication(catId, "薬", twenty + "あ", "08:00"),
                medication(catId, "薬", null, "24:00"),
                medication(catId, "薬", null, "8:00"),
                medication(catId, "薬", null, "08:60"),
                medication(catId, "薬", null, null));
        List<Map<String, Object>> sent = new ArrayList<>();
        for (Map<String, Object> d : data) {
            sent.add(change("medication_schedules", UUID.randomUUID(), d));
        }
        assertThat(reasons(syncBody(haru, 0, sent))).containsExactly(null, null, "invalid:name", "invalid:name",
                "invalid:dose", "invalid:timeOfDay", "invalid:timeOfDay", "invalid:timeOfDay", "invalid:timeOfDay");
    }

    @Test
    @DisplayName("IT-SY-26 お薬の予定の権限：ほかのおうちの猫・おうちは rejected、知らない猫は not_found、おうちの付け替えは受け付けず、ほかのおうちの予定は届かない")
    void お薬の予定の権限() throws Exception {
        UUID catId = UUID.randomUUID();
        syncBody(haru, 0, List.of(change("cats", catId, cat("ミケ"))));
        Registered other = TestUsers.register(mvc);
        UUID otherHousehold = UUID.randomUUID();
        createHousehold(other, otherHousehold, UUID.randomUUID()).andExpect(status().isCreated());
        UUID otherCat = UUID.randomUUID();
        Map<String, Object> otherCatData = Map.of("householdId", otherHousehold.toString(), "name", "タマ",
                "status", "active");
        syncBody(other, 0, List.of(change("cats", otherCat, otherCatData)));

        UUID mine = UUID.randomUUID();
        Map<String, Object> intoOther = medication(catId, "薬", null, "08:00");
        intoOther.put("householdId", otherHousehold.toString());
        Map<String, Object> moved = medication(catId, "薬", null, "08:00");
        moved.put("householdId", otherHousehold.toString());
        Map<String, Object> body = syncBody(haru, 0, List.of(
                change("medication_schedules", mine, medication(catId, "薬", null, "08:00")),
                change("medication_schedules", UUID.randomUUID(), medication(otherCat, "薬", null, "08:00")),
                change("medication_schedules", UUID.randomUUID(), intoOther),
                change("medication_schedules", UUID.randomUUID(), medication(UUID.randomUUID(), "薬", null, "08:00"))));
        assertThat(reasons(body)).containsExactly(null, "forbidden:catId", "forbidden", "not_found:catId");

        // ほかの人が、自分のおうちに付け替えようとしても受け付けない
        Map<String, Object> steal = new LinkedHashMap<>(medication(otherCat, "薬", null, "08:00"));
        steal.put("householdId", otherHousehold.toString());
        assertThat(statuses(syncBody(other, 0, List.of(change("medication_schedules", mine, steal)))))
                .containsExactly("rejected");
        assertThat(changes(syncBody(other, 0, List.of()), "medication_schedules")).isEmpty();
    }
}
