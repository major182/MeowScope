-- 退会した人のメンバーの行を、削除の印を付けたまま残す（DB 設計書 7章）。
-- 行が物理削除されると、相手の端末へ「抜けた」ことが同期で届かないため、ユーザーの ID だけを空にする
ALTER TABLE household_members ALTER COLUMN user_id DROP NOT NULL;
ALTER TABLE household_members DROP CONSTRAINT household_members_user_id_fkey;
ALTER TABLE household_members
    ADD CONSTRAINT household_members_user_id_fkey FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE SET NULL;
