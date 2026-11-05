package com.meowscope.server.sync;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/** 同期の API の要求と応答（API 設計書 5章）。 */
public final class SyncDtos {

    /** 1回で送受信する件数の上限。 */
    public static final int MAX_CHANGES = 500;

    private SyncDtos() {
    }

    /**
     * 要求。
     *
     * @param lastSeq 端末が最後に受け取った通し番号。初めては 0
     * @param changes 端末の変更。行の今の内容を丸ごと送る
     */
    public record SyncRequest(
            @Min(0) long lastSeq,
            @NotNull @Size(max = MAX_CHANGES) List<@Valid @NotNull ChangeIn> changes) {
    }

    public record ChangeIn(
            @NotBlank @Size(max = 30) String table,
            @NotNull UUID id,
            String updatedAt,
            String deletedAt,
            Map<String, Object> data) {
    }

    /**
     * 1件ごとの結果。{@code applied}・{@code ignored}・{@code rejected}。
     *
     * <p>{@code rejected} のときは、理由（{@code reason}）と、値の誤りなら項目の名前（{@code field}）も返す。
     * 端末はこれで、どの変更がなぜ送れなかったかを利用者に示す（Issue #83）。それ以外のときは null
     */
    public record Result(UUID id, String status, String reason, String field) {
        Result(UUID id, String status) {
            this(id, status, null, null);
        }
    }

    /** サーバーから端末へ送る変更。{@code seq} はその行の通し番号。 */
    public record ChangeOut(String table, UUID id, long seq, String updatedAt, String deletedAt,
            Map<String, Object> data) {
    }

    public record SyncResponse(List<Result> results, List<ChangeOut> changes, long nextSeq, boolean hasMore,
            boolean fullResyncRequired) {
    }
}
