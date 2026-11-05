package com.meowscope.server.sync;

import com.meowscope.server.household.HouseholdAccess;
import com.meowscope.server.photo.PhotoStorage;
import com.meowscope.server.sync.Fields.Rejected;
import com.meowscope.server.sync.SyncDtos.ChangeIn;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;
import tools.jackson.databind.json.JsonMapper;

/**
 * 端末から来た変更を1件ずつ DB に反映する（API 設計書 5章、BR-10、BR-11）。
 *
 * <ul>
 *   <li>競合：後から受け取った変更で上書きする。更新日時は比べない（端末の時計を信用しない）
 *   <li>送り直し：今の内容と同じなら何もせず {@code ignored} を返す。通し番号を進めないので、相手の端末へ同じ変更が何度も届かない
 *   <li>権限：行のおうちと、変更の後のおうちの両方が、自分の属するおうちであること（NF-SC-04）。おうちの付け替えは受け付けない
 * </ul>
 *
 * <p>更新は {@code ROW(...) IS DISTINCT FROM ROW(...)} の条件付きで行い、内容が同じなら 0 行になることで送り直しを見分ける。
 */
@Component
class SyncWriter {

    static final String APPLIED = "applied";
    static final String IGNORED = "ignored";

    private static final Set<String> KINDS =
            Set.of("food", "water", "medicine", "urine", "stool", "vomit", "weight", "brushing", "custom");
    private static final Set<String> LEVELS = Set.of("little", "normal", "much");
    private static final Set<String> SEXES = Set.of("male", "female", "unknown");
    private static final Set<String> CAT_STATUSES = Set.of("active", "farewell");
    private static final Set<String> WEEK_STARTS = Set.of("sunday", "monday");

    private final JdbcClient jdbc;
    private final HouseholdAccess access;
    private final JsonMapper json;
    private final PhotoStorage storage;

    SyncWriter(JdbcClient jdbc, HouseholdAccess access, JsonMapper json, PhotoStorage storage) {
        this.jdbc = jdbc;
        this.access = access;
        this.json = json;
        this.storage = storage;
    }

    /** 表ごとに反映する。表の名前が知らないものなら受け付けない。 */
    String apply(UUID userId, ChangeIn change) {
        Fields f = new Fields(change.data(), json);
        Timestamp updatedAt = change.updatedAt() == null
                ? Timestamp.from(Instant.now()) : Fields.parseInstant(change.updatedAt(), "updatedAt");
        Timestamp deletedAt = change.deletedAt() == null ? null : Fields.parseInstant(change.deletedAt(), "deletedAt");
        return switch (change.table()) {
            case "households" -> household(userId, change.id(), f, updatedAt, deletedAt);
            case "cats" -> cat(userId, change.id(), f, updatedAt, deletedAt);
            case "record_types" -> recordType(userId, change.id(), f, updatedAt, deletedAt);
            case "records" -> record(userId, change.id(), f, updatedAt, deletedAt);
            case "record_photos" -> photo(userId, change.id(), f, updatedAt, deletedAt);
            case "user_settings" -> userSettings(userId, f, updatedAt);
            case "widget_buttons" -> widgetButton(userId, change.id(), f, updatedAt, deletedAt);
            default -> throw new Rejected("unknown_table", null);
        };
    }

    /** 送る順番。参照される側（おうち・猫・記録項目）を先に反映する。 */
    static int order(String table) {
        return switch (table) {
            case "households" -> 0;
            case "cats", "record_types" -> 1;
            case "records", "widget_buttons" -> 2;
            case "record_photos" -> 3;
            default -> 4;
        };
    }

    private void requireMember(UUID userId, UUID householdId) {
        if (!access.isMember(userId, householdId)) {
            throw new Rejected("forbidden", null);
        }
    }

    /** 既にある行なら、そのおうちが変更の後と同じで、自分のおうちであることを確かめる。 */
    private boolean checkExisting(UUID userId, Optional<UUID> existing, UUID target) {
        if (existing.isEmpty()) {
            return false;
        }
        if (!existing.get().equals(target)) {
            throw new Rejected("forbidden", null);
        }
        requireMember(userId, existing.get());
        return true;
    }

    private static String result(int updated) {
        return updated == 1 ? APPLIED : IGNORED;
    }

    private String household(UUID userId, UUID id, Fields f, Timestamp updatedAt, Timestamp deletedAt) {
        // おうちの作成は POST /households で行う。ここでは名前の変更だけを受け付ける。削除はおうちを抜ける操作で行う
        if (!access.householdExists(id)) {
            throw new Rejected("not_found", null);
        }
        requireMember(userId, id);
        String name = f.text("name", true, 50);
        return result(jdbc.sql("""
                UPDATE households SET name = :name, updated_at = :updatedAt, server_seq = nextval('sync_seq')
                WHERE id = :id AND name IS DISTINCT FROM :name
                """).param("id", id).param("name", name).param("updatedAt", updatedAt).update());
    }

    private String cat(UUID userId, UUID id, Fields f, Timestamp updatedAt, Timestamp deletedAt) {
        UUID household = f.uuid("householdId");
        requireMember(userId, household);
        Object[] values = {
            f.text("name", true, 50), f.date("birthDate"), f.oneOf("sex", false, SEXES),
            f.text("conditions", false, 500), f.oneOf("status", true, CAT_STATUSES),
        };
        if (checkExisting(userId, access.householdOfCat(id), household)) {
            return result(jdbc.sql("""
                    UPDATE cats SET name = :name, birth_date = :birth, sex = :sex, conditions = :conditions,
                      status = :status, deleted_at = :deletedAt, updated_at = :updatedAt,
                      server_seq = nextval('sync_seq')
                    WHERE id = :id AND ROW(name, birth_date, sex, conditions, status, deleted_at)
                      IS DISTINCT FROM ROW(CAST(:name AS text), CAST(:birth AS date), CAST(:sex AS text),
                        CAST(:conditions AS text), CAST(:status AS text), CAST(:deletedAt AS timestamptz))
                    """)
                    .param("id", id).param("name", values[0]).param("birth", values[1]).param("sex", values[2])
                    .param("conditions", values[3]).param("status", values[4]).param("deletedAt", deletedAt)
                    .param("updatedAt", updatedAt).update());
        }
        jdbc.sql("""
                INSERT INTO cats (id, household_id, name, birth_date, sex, conditions, status, deleted_at, updated_at)
                VALUES (:id, :household, :name, :birth, :sex, :conditions, :status, :deletedAt, :updatedAt)
                """)
                .param("id", id).param("household", household).param("name", values[0]).param("birth", values[1])
                .param("sex", values[2]).param("conditions", values[3]).param("status", values[4])
                .param("deletedAt", deletedAt).param("updatedAt", updatedAt).update();
        return APPLIED;
    }

    private String recordType(UUID userId, UUID id, Fields f, Timestamp updatedAt, Timestamp deletedAt) {
        UUID household = f.uuid("householdId");
        requireMember(userId, household);
        String name = f.text("name", true, 20);
        String icon = f.text("icon", false, 50);
        String kind = f.oneOf("kind", true, KINDS);
        Integer sort = f.integer("sortOrder", 0, 1000);
        boolean hidden = f.bool("hidden");
        if (checkExisting(userId, access.householdOfRecordType(id), household)) {
            return result(jdbc.sql("""
                    UPDATE record_types SET name = :name, icon = :icon, kind = :kind, sort_order = :sort,
                      hidden = :hidden, deleted_at = :deletedAt, updated_at = :updatedAt,
                      server_seq = nextval('sync_seq')
                    WHERE id = :id AND ROW(name, icon, kind, sort_order, hidden, deleted_at)
                      IS DISTINCT FROM ROW(CAST(:name AS text), CAST(:icon AS text), CAST(:kind AS text),
                        CAST(:sort AS integer), CAST(:hidden AS boolean), CAST(:deletedAt AS timestamptz))
                    """)
                    .param("id", id).param("name", name).param("icon", icon).param("kind", kind).param("sort", sort)
                    .param("hidden", hidden).param("deletedAt", deletedAt).param("updatedAt", updatedAt).update());
        }
        jdbc.sql("""
                INSERT INTO record_types (id, household_id, name, icon, kind, sort_order, hidden, deleted_at,
                  updated_at)
                VALUES (:id, :household, :name, :icon, :kind, :sort, :hidden, :deletedAt, :updatedAt)
                """)
                .param("id", id).param("household", household).param("name", name).param("icon", icon)
                .param("kind", kind).param("sort", sort).param("hidden", hidden).param("deletedAt", deletedAt)
                .param("updatedAt", updatedAt).update();
        return APPLIED;
    }

    private String record(UUID userId, UUID id, Fields f, Timestamp updatedAt, Timestamp deletedAt) {
        UUID catId = f.uuid("catId");
        UUID typeId = f.uuid("recordTypeId");
        // 猫と記録項目は同じおうちのもので、自分のおうちであること
        UUID household = access.householdOfCat(catId).orElseThrow(() -> new Rejected("not_found", "catId"));
        UUID typeHousehold = access.householdOfRecordType(typeId)
                .orElseThrow(() -> new Rejected("not_found", "recordTypeId"));
        if (!typeHousehold.equals(household)) {
            throw new Rejected("forbidden", "recordTypeId");
        }
        requireMember(userId, household);
        Object[] v = {
            f.instant("recordedAt", true), f.text("authorName", true, 20), f.number("valueNumber", 0, 1000),
            f.oneOf("level", false, LEVELS), f.object("detail", 4000), f.text("memo", false, 1000),
        };
        if (checkExisting(userId, access.householdOfRecord(id), household)) {
            // 投稿者（author_id）は最初に作った人のまま。編集した人には変えない（BR-17）
            return result(jdbc.sql("""
                    UPDATE records SET cat_id = :cat, record_type_id = :type, recorded_at = :recordedAt,
                      author_name = :authorName, value_number = :value, level = :level,
                      detail = CAST(:detail AS jsonb), memo = :memo, deleted_at = :deletedAt,
                      updated_at = :updatedAt, server_seq = nextval('sync_seq')
                    WHERE id = :id AND ROW(cat_id, record_type_id, recorded_at, author_name, value_number, level,
                        detail, memo, deleted_at)
                      IS DISTINCT FROM ROW(CAST(:cat AS uuid), CAST(:type AS uuid), CAST(:recordedAt AS timestamptz),
                        CAST(:authorName AS text), CAST(:value AS numeric), CAST(:level AS text),
                        CAST(:detail AS jsonb), CAST(:memo AS text), CAST(:deletedAt AS timestamptz))
                    """)
                    .param("id", id).param("cat", catId).param("type", typeId).param("recordedAt", v[0])
                    .param("authorName", v[1]).param("value", v[2]).param("level", v[3]).param("detail", v[4])
                    .param("memo", v[5]).param("deletedAt", deletedAt).param("updatedAt", updatedAt).update());
        }
        // 投稿者の ID は端末の申告ではなく、トークンのユーザーにする
        jdbc.sql("""
                INSERT INTO records (id, cat_id, record_type_id, recorded_at, author_id, author_name, value_number,
                  level, detail, memo, deleted_at, updated_at)
                VALUES (:id, :cat, :type, :recordedAt, :author, :authorName, :value, :level, CAST(:detail AS jsonb),
                  :memo, :deletedAt, :updatedAt)
                """)
                .param("id", id).param("cat", catId).param("type", typeId).param("recordedAt", v[0])
                .param("author", userId).param("authorName", v[1]).param("value", v[2]).param("level", v[3])
                .param("detail", v[4]).param("memo", v[5]).param("deletedAt", deletedAt)
                .param("updatedAt", updatedAt).update();
        return APPLIED;
    }

    /** 1つの記録に付けられる写真の数（データ要件、AC-03）。 */
    static final int MAX_PHOTOS = 3;

    /**
     * 写真の情報（どの記録の何枚目か）。画像の本体は PUT /photos で後から届く。
     * 削除の印が付いたら、サーバーの画像のファイルも消す（DB 設計書 7章）。
     */
    private String photo(UUID userId, UUID id, Fields f, Timestamp updatedAt, Timestamp deletedAt) {
        UUID recordId = f.uuid("recordId");
        Integer sort = f.integer("sortOrder", 1, MAX_PHOTOS);
        if (sort == null) {
            throw new Rejected("invalid", "sortOrder");
        }
        UUID household = access.householdOfRecord(recordId).orElseThrow(() -> new Rejected("not_found", "recordId"));
        requireMember(userId, household);
        if (deletedAt == null) {
            long others = jdbc.sql("""
                    SELECT count(*) FROM record_photos
                    WHERE record_id = :record AND deleted_at IS NULL AND id <> :id
                    """).param("record", recordId).param("id", id).query(Long.class).single();
            if (others >= MAX_PHOTOS) {
                throw new Rejected("too_many", null);
            }
        }
        if (checkExisting(userId, access.householdOfPhoto(id), household)) {
            String path = jdbc.sql("SELECT file_path FROM record_photos WHERE id = :id").param("id", id)
                    .query(String.class).optional().orElse(null);
            String status = result(jdbc.sql("""
                    UPDATE record_photos SET record_id = :record, sort_order = :sort, deleted_at = :deletedAt,
                      updated_at = :updatedAt, server_seq = nextval('sync_seq')
                    WHERE id = :id AND ROW(record_id, sort_order, deleted_at)
                      IS DISTINCT FROM ROW(CAST(:record AS uuid), CAST(:sort AS integer),
                        CAST(:deletedAt AS timestamptz))
                    """).param("id", id).param("record", recordId).param("sort", sort)
                    .param("deletedAt", deletedAt).param("updatedAt", updatedAt).update());
            if (deletedAt != null && APPLIED.equals(status)) {
                storage.delete(path);
            }
            return status;
        }
        jdbc.sql("""
                INSERT INTO record_photos (id, record_id, sort_order, deleted_at, updated_at)
                VALUES (:id, :record, :sort, :deletedAt, :updatedAt)
                """).param("id", id).param("record", recordId).param("sort", sort).param("deletedAt", deletedAt)
                .param("updatedAt", updatedAt).update();
        return APPLIED;
    }

    /** 1人が登録できるウィジェットのボタンの数（画面設計書 S-44）。 */
    static final int MAX_WIDGET_BUTTONS = 4;

    /**
     * ウィジェットのボタン（BR-22）。持ち主はトークンのユーザーで、他の人のボタンは変えられない。
     * 記録項目は自分の属するおうちのものであること。
     */
    private String widgetButton(UUID userId, UUID id, Fields f, Timestamp updatedAt, Timestamp deletedAt) {
        UUID typeId = f.uuid("recordTypeId");
        Integer sort = f.integer("sortOrder", 0, MAX_WIDGET_BUTTONS - 1);
        UUID household = access.householdOfRecordType(typeId)
                .orElseThrow(() -> new Rejected("not_found", "recordTypeId"));
        requireMember(userId, household);
        Optional<UUID> owner = jdbc.sql("SELECT user_id FROM widget_buttons WHERE id = :id").param("id", id)
                .query(UUID.class).optional();
        if (owner.isPresent() && !owner.get().equals(userId)) {
            throw new Rejected("forbidden", null);
        }
        if (deletedAt == null) {
            long others = jdbc.sql("""
                    SELECT count(*) FROM widget_buttons WHERE user_id = :user AND deleted_at IS NULL AND id <> :id
                    """).param("user", userId).param("id", id).query(Long.class).single();
            if (others >= MAX_WIDGET_BUTTONS) {
                throw new Rejected("too_many", null);
            }
        }
        if (owner.isPresent()) {
            return result(jdbc.sql("""
                    UPDATE widget_buttons SET record_type_id = :type, sort_order = :sort, deleted_at = :deletedAt,
                      updated_at = :updatedAt, server_seq = nextval('sync_seq')
                    WHERE id = :id AND ROW(record_type_id, sort_order, deleted_at)
                      IS DISTINCT FROM ROW(CAST(:type AS uuid), CAST(:sort AS integer),
                        CAST(:deletedAt AS timestamptz))
                    """).param("id", id).param("type", typeId).param("sort", sort)
                    .param("deletedAt", deletedAt).param("updatedAt", updatedAt).update());
        }
        jdbc.sql("""
                INSERT INTO widget_buttons (id, user_id, record_type_id, sort_order, deleted_at, updated_at)
                VALUES (:id, :user, :type, :sort, :deletedAt, :updatedAt)
                """).param("id", id).param("user", userId).param("type", typeId).param("sort", sort)
                .param("deletedAt", deletedAt).param("updatedAt", updatedAt).update();
        return APPLIED;
    }

    /** 自分の設定。行は登録のときにできているので、ID は見ずに自分の行を更新する。 */
    private String userSettings(UUID userId, Fields f, Timestamp updatedAt) {
        String weekStart = f.oneOf("weekStart", true, WEEK_STARTS);
        return result(jdbc.sql("""
                UPDATE user_settings SET week_start = :weekStart, updated_at = :updatedAt,
                  server_seq = nextval('sync_seq')
                WHERE user_id = :user AND week_start IS DISTINCT FROM :weekStart
                """).param("user", userId).param("weekStart", weekStart).param("updatedAt", updatedAt).update());
    }
}
