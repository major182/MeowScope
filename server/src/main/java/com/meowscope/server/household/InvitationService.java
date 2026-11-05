package com.meowscope.server.household;

import com.meowscope.server.common.error.ApiException;
import com.meowscope.server.common.error.ErrorCode;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.HexFormat;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * リンクでおうちへ招待する（F-SH-04、API 設計書 4章）。2026-11-04 決定：LINE などで渡すリンクをメインとする。
 *
 * <ul>
 *   <li>リンクには推測できないランダムな値（トークン）を入れ、DB にはハッシュだけを置く
 *   <li>有効なのは作ってから1時間、1回だけ。転送されても、使えるのは最初の1人だけ
 * </ul>
 */
@Service
public class InvitationService {

    private static final Logger log = LoggerFactory.getLogger(InvitationService.class);
    private static final SecureRandom RANDOM = new SecureRandom();

    /** リンクの有効期間。 */
    static final Duration TTL = Duration.ofHours(1);

    /** アプリを開くリンクの形。Android はこの形のリンクを押すとアプリが開く。 */
    static final String LINK_PREFIX = "meowscope://invite?token=";

    private final JdbcClient jdbc;
    private final HouseholdAccess access;
    private final Clock clock;

    InvitationService(JdbcClient jdbc, HouseholdAccess access, Clock clock) {
        this.jdbc = jdbc;
        this.access = access;
        this.clock = clock;
    }

    /** 作った招待。トークンはこの応答にしか出さない（ログにも出さない）。 */
    public record Invitation(String token, String link, Instant expiresAt) {
    }

    @Transactional
    public Invitation create(UUID userId, UUID householdId) {
        if (!access.isMember(userId, householdId)) {
            throw new ApiException(ErrorCode.NOT_FOUND);
        }
        byte[] random = new byte[32];
        RANDOM.nextBytes(random);
        String token = Base64.getUrlEncoder().withoutPadding().encodeToString(random);
        Instant expires = clock.instant().plus(TTL);
        jdbc.sql("""
                INSERT INTO invitations (id, household_id, token_hash, expires_at)
                VALUES (:id, :h, :hash, :exp)
                """).param("id", UUID.randomUUID()).param("h", householdId).param("hash", hash(token))
                .param("exp", Timestamp.from(expires)).update();
        log.atInfo().addKeyValue("evt.name", "invitation_create").addKeyValue("usr.id", userId.toString())
                .addKeyValue("household.id", householdId.toString()).log("招待のリンクを作成");
        return new Invitation(token, LINK_PREFIX + token, expires);
    }

    /**
     * 招待を受ける。
     *
     * @return 参加したおうちの ID
     * @throws ApiException 知らない・期限切れ・使用済みのリンクは 404（どれかは教えない）
     */
    @Transactional
    public UUID accept(UUID userId, String token) {
        record Row(UUID id, UUID householdId, Instant expiresAt, Instant usedAt) {
        }
        Row row = jdbc.sql("""
                SELECT id, household_id, expires_at, used_at FROM invitations WHERE token_hash = :hash FOR UPDATE
                """).param("hash", hash(token)).query(Row.class).optional()
                .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND));
        if (row.usedAt() != null || !row.expiresAt().isAfter(clock.instant())
                || !access.householdExists(row.householdId())) {
            throw new ApiException(ErrorCode.NOT_FOUND);
        }
        jdbc.sql("UPDATE invitations SET used_at = now() WHERE id = :id").param("id", row.id()).update();
        if (!access.isMember(userId, row.householdId())) {
            jdbc.sql("INSERT INTO household_members (id, household_id, user_id) VALUES (:id, :h, :u)")
                    .param("id", UUID.randomUUID()).param("h", row.householdId()).param("u", userId).update();
            // 加わった人のユーザーの行（表示名・アイコンの有無）は番号が古く、前からいるメンバーへ差分で届かない。番号を進める
            jdbc.sql("UPDATE users SET server_seq = nextval('sync_seq') WHERE id = :u").param("u", userId).update();
        }
        log.atInfo().addKeyValue("evt.name", "invitation_accept").addKeyValue("evt.outcome", "success")
                .addKeyValue("usr.id", userId.toString()).addKeyValue("household.id", row.householdId().toString())
                .log("招待を受けた");
        return row.householdId();
    }

    static String hash(String token) {
        try {
            return HexFormat.of().formatHex(
                    MessageDigest.getInstance("SHA-256").digest(token.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }
}
