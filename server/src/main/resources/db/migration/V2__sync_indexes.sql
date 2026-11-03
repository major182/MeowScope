-- 同期の差分の取得（server_seq より後の行）と、おうちの権限の確認を速くする（NF-PF-04）
CREATE INDEX households_seq_idx ON households (server_seq);
CREATE INDEX household_members_seq_idx ON household_members (server_seq);
CREATE INDEX household_members_user_idx ON household_members (user_id);
CREATE INDEX users_seq_idx ON users (server_seq);
CREATE INDEX user_settings_seq_idx ON user_settings (server_seq);
CREATE INDEX cats_household_seq_idx ON cats (household_id, server_seq);
CREATE INDEX record_types_household_seq_idx ON record_types (household_id, server_seq);
CREATE INDEX records_seq_idx ON records (server_seq);
