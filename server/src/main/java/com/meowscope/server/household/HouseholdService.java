package com.meowscope.server.household;

import com.meowscope.server.common.error.ApiException;
import com.meowscope.server.common.error.ErrorCode;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** おうちの作成（API 設計書 4章、F-SH-02、BR-21）。 */
@Service
public class HouseholdService {

    private static final Logger log = LoggerFactory.getLogger(HouseholdService.class);

    /** 標準の項目「病院」の種類・名前・アイコン（V9 と同じ値。DB 設計書 4章）。 */
    static final String VET = "vet";
    static final String VET_NAME = "病院";
    static final String VET_ICON = "custom_vet";

    private final JdbcClient jdbc;
    private final HouseholdAccess access;

    HouseholdService(JdbcClient jdbc, HouseholdAccess access) {
        this.jdbc = jdbc;
        this.access = access;
    }

    /**
     * 端末で作ったおうちと記録項目を ID ごと登録し、作った人をメンバーにする。
     * 標準の項目は端末が作って送る。ただし病院（vet）が含まれていなければ（Ver.1.3.0 より前のアプリ）、
     * サーバーが1つ足す（BR-37。1つのおうちに1つだけにするため、端末に作らせない）。
     *
     * @return 新しく作ったら true。自分のおうちとして登録済みなら false（送り直し）
     * @throws ApiException 他の人のおうちの ID だったとき（404。存在するかどうかも教えない）
     */
    @Transactional
    boolean create(UUID userId, HouseholdController.CreateRequest request) {
        if (access.householdExists(request.id())) {
            if (access.isMember(userId, request.id())) {
                return false;
            }
            throw new ApiException(ErrorCode.NOT_FOUND);
        }
        jdbc.sql("INSERT INTO households (id, name) VALUES (:id, :name)")
                .param("id", request.id()).param("name", request.name().strip()).update();
        jdbc.sql("INSERT INTO household_members (id, household_id, user_id) VALUES (:id, :household, :user)")
                .param("id", UUID.randomUUID()).param("household", request.id()).param("user", userId).update();
        for (HouseholdController.RecordTypeInput type : request.recordTypes()) {
            try {
                jdbc.sql("""
                        INSERT INTO record_types (id, household_id, name, icon, kind, sort_order)
                        VALUES (:id, :household, :name, :icon, :kind, :sort)
                        """)
                        .param("id", type.id()).param("household", request.id()).param("name", type.name().strip())
                        .param("icon", type.icon()).param("kind", type.kind()).param("sort", type.sortOrder())
                        .update();
            } catch (DuplicateKeyException e) {
                // 記録項目の ID が、ほかのおうちの項目とぶつかった。おうちごと作らず 409 にする（UUID なので実際にはまず起きない）
                throw new ApiException(ErrorCode.CONFLICT);
            }
        }
        if (request.recordTypes().stream().noneMatch(t -> VET.equals(t.kind()))) {
            jdbc.sql("""
                    INSERT INTO record_types (id, household_id, name, icon, kind, sort_order)
                    VALUES (:id, :household, :name, :icon, :kind,
                            (SELECT COALESCE(max(sort_order), -1) + 1 FROM record_types WHERE household_id = :household))
                    """)
                    .param("id", UUID.randomUUID()).param("household", request.id()).param("name", VET_NAME)
                    .param("icon", VET_ICON).param("kind", VET).update();
        }
        log.atInfo().addKeyValue("evt.name", "household_create").addKeyValue("evt.outcome", "success")
                .addKeyValue("household.id", request.id().toString())
                .log("おうちを作成");
        return true;
    }
}
