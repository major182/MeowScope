package com.meowscope.server.sync;

import com.meowscope.server.sync.Fields.Rejected;
import com.meowscope.server.sync.SyncDtos.ChangeIn;
import com.meowscope.server.sync.SyncDtos.ChangeOut;
import com.meowscope.server.sync.SyncDtos.Result;
import com.meowscope.server.sync.SyncDtos.SyncRequest;
import com.meowscope.server.sync.SyncDtos.SyncResponse;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * 同期（POST /sync）。端末の変更を反映し、続けて相手の変更を返す（API 設計書 5章）。
 *
 * <p>変更は1件ずつ別のトランザクションで反映する。1件が受け付けられなくても、ほかの変更は反映する。
 * 結果は送られた順に返す。
 */
@Service
public class SyncService {

    private static final Logger log = LoggerFactory.getLogger(SyncService.class);
    static final String REJECTED = "rejected";

    private final SyncWriter writer;
    private final SyncReader reader;
    private final TransactionTemplate transaction;

    SyncService(SyncWriter writer, SyncReader reader, TransactionTemplate transaction) {
        this.writer = writer;
        this.reader = reader;
        this.transaction = transaction;
    }

    public SyncResponse sync(UUID userId, SyncRequest request) {
        List<ChangeIn> ordered = new ArrayList<>(request.changes());
        ordered.sort(Comparator.comparingInt(c -> SyncWriter.order(c.table())));
        java.util.Map<ChangeIn, Result> outcomes = new java.util.IdentityHashMap<>();
        for (ChangeIn change : ordered) {
            outcomes.put(change, apply(userId, change));
        }
        List<Result> results = request.changes().stream().map(outcomes::get).toList();

        boolean full = reader.fullResyncRequired(userId, request.lastSeq());
        List<ChangeOut> changes = full ? List.of() : reader.read(userId, request.lastSeq(), SyncDtos.MAX_CHANGES);
        boolean hasMore = changes.size() > SyncDtos.MAX_CHANGES;
        if (hasMore) {
            changes = changes.subList(0, SyncDtos.MAX_CHANGES);
        }
        long nextSeq = changes.isEmpty() ? request.lastSeq() : changes.getLast().seq();

        log.atInfo().addKeyValue("evt.name", "sync").addKeyValue("evt.outcome", "success")
                .addKeyValue("sync.received", results.size())
                .addKeyValue("sync.applied", count(results, SyncWriter.APPLIED))
                .addKeyValue("sync.ignored", count(results, SyncWriter.IGNORED))
                .addKeyValue("sync.rejected", count(results, REJECTED))
                .addKeyValue("sync.sent", changes.size())
                .log("同期");
        return new SyncResponse(results, changes, full ? request.lastSeq() : nextSeq, hasMore, full);
    }

    private Result apply(UUID userId, ChangeIn change) {
        try {
            return new Result(change.id(), transaction.execute(status -> writer.apply(userId, change)));
        } catch (Rejected e) {
            reject(change, e.reason(), e.getMessage());
            return new Result(change.id(), REJECTED, e.reason(), e.field());
        } catch (DataIntegrityViolationException e) {
            // 参照先がない・制約に反するなど、端末の内容の誤り
            reject(change, "constraint", null);
            return new Result(change.id(), REJECTED, "constraint", null);
        }
    }

    /** 受け付けなかった変更は、後で確かめられるよう warning で残す。内容は出さず、表と ID と理由だけ（ログ設計書 6章）。 */
    private static void reject(ChangeIn change, String reason, String detail) {
        log.atWarn().addKeyValue("evt.name", "sync_rejected").addKeyValue("evt.outcome", "failure")
                .addKeyValue("evt.reason", detail == null ? reason : detail)
                .log("同期の変更を受け付けなかった（表：{}、ID：{}）", change.table(), change.id());
    }

    private static long count(List<Result> results, String status) {
        return results.stream().filter(r -> r.status().equals(status)).count();
    }
}
