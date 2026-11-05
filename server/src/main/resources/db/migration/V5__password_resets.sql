-- パスワードの再設定の確認コード（API 設計書 2章、F-AU-03）。
-- 1人に1つだけ。送り直すと置き換える。コードはハッシュだけを置き、15分で期限が切れる。5回間違えたら使えなくする
CREATE TABLE password_resets (
    user_id    uuid PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE,
    code_hash  text        NOT NULL,
    expires_at timestamptz NOT NULL,
    attempts   integer     NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now()
);
