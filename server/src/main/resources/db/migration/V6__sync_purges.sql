-- 完全に消した行の通し番号の最大（DB 設計書 7章、API 設計書 5章）。1行だけ持つ。
-- これより前の位置から同期してきた端末は、消えた行の削除を受け取れないので、全件を取り直させる
CREATE TABLE sync_purges (
    id          integer PRIMARY KEY CHECK (id = 1),
    purged_seq  bigint      NOT NULL DEFAULT 0,
    purged_at   timestamptz
);
INSERT INTO sync_purges (id, purged_seq) VALUES (1, 0);
