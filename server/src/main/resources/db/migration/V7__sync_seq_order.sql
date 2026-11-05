-- 通し番号を、確定（コミット）の順に振る（BR-10、API 設計書 5章）
--
-- nextval は呼んだ時点で番号を取るので、番号の大きいトランザクションが先に確定することがある。
-- その間に同期した端末は大きい番号まで進み、後から確定した小さい番号の行を受け取れなくなる。
-- そこで番号を振る処理をトランザクション単位のロックで1つずつにし、ロックは確定まで持つ。
-- 端末へ変更を読む側は、同じロックを共有で取ってから読む（SyncReader）。

-- 番号を振るときに取るロックの番号（アプリの中で、このロックにだけ使う）
CREATE FUNCTION sync_lock_key() RETURNS bigint LANGUAGE sql IMMUTABLE AS 'SELECT 7239001::bigint';

-- ロックを取ってから次の番号を返す。トリガーと、行を完全に消したときの purged_seq に使う
CREATE FUNCTION sync_next_seq() RETURNS bigint LANGUAGE plpgsql AS $$
BEGIN
    PERFORM pg_advisory_xact_lock(sync_lock_key());
    RETURN nextval('sync_seq');
END
$$;

-- 追加した行と、番号を進めた更新の行に、ロックを取って番号を振り直す。
-- SQL の nextval（列の既定値・UPDATE の SET）で取った番号は使わず、欠番になる
CREATE FUNCTION sync_assign_seq() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'INSERT' OR NEW.server_seq IS DISTINCT FROM OLD.server_seq THEN
        NEW.server_seq := sync_next_seq();
    END IF;
    RETURN NEW;
END
$$;

CREATE TRIGGER users_seq BEFORE INSERT OR UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION sync_assign_seq();
CREATE TRIGGER user_settings_seq BEFORE INSERT OR UPDATE ON user_settings
    FOR EACH ROW EXECUTE FUNCTION sync_assign_seq();
CREATE TRIGGER households_seq BEFORE INSERT OR UPDATE ON households
    FOR EACH ROW EXECUTE FUNCTION sync_assign_seq();
CREATE TRIGGER household_members_seq BEFORE INSERT OR UPDATE ON household_members
    FOR EACH ROW EXECUTE FUNCTION sync_assign_seq();
CREATE TRIGGER cats_seq BEFORE INSERT OR UPDATE ON cats
    FOR EACH ROW EXECUTE FUNCTION sync_assign_seq();
CREATE TRIGGER record_types_seq BEFORE INSERT OR UPDATE ON record_types
    FOR EACH ROW EXECUTE FUNCTION sync_assign_seq();
CREATE TRIGGER records_seq BEFORE INSERT OR UPDATE ON records
    FOR EACH ROW EXECUTE FUNCTION sync_assign_seq();
CREATE TRIGGER record_photos_seq BEFORE INSERT OR UPDATE ON record_photos
    FOR EACH ROW EXECUTE FUNCTION sync_assign_seq();
CREATE TRIGGER widget_buttons_seq BEFORE INSERT OR UPDATE ON widget_buttons
    FOR EACH ROW EXECUTE FUNCTION sync_assign_seq();
