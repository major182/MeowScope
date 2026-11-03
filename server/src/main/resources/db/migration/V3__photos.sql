-- 写真（API 設計書 6章）。写真の情報は同期で先に届き、画像は後から送られるので、
-- 送られるまでは保存場所が空になる
ALTER TABLE record_photos ALTER COLUMN file_path DROP NOT NULL;
CREATE INDEX record_photos_record_idx ON record_photos (record_id);
CREATE INDEX record_photos_seq_idx ON record_photos (server_seq);
