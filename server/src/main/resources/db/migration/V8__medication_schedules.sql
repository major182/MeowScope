-- お薬の予定（DB 設計書 4章、F-MD-02、BR-06）。おうちのもので、家族と共有する
CREATE TABLE medication_schedules (
    id           uuid PRIMARY KEY,
    household_id uuid        NOT NULL REFERENCES households (id) ON DELETE CASCADE,
    cat_id       uuid        NOT NULL REFERENCES cats (id) ON DELETE CASCADE,
    name         text        NOT NULL,
    dose         text,
    time_of_day  text        NOT NULL,
    enabled      boolean     NOT NULL DEFAULT true,
    created_at   timestamptz NOT NULL DEFAULT now(),
    updated_at   timestamptz NOT NULL DEFAULT now(),
    deleted_at   timestamptz,
    server_seq   bigint      NOT NULL DEFAULT nextval('sync_seq'),
    CONSTRAINT medication_schedules_name_check CHECK (char_length(name) BETWEEN 1 AND 20),
    CONSTRAINT medication_schedules_dose_check CHECK (dose IS NULL OR char_length(dose) <= 20),
    CONSTRAINT medication_schedules_time_check CHECK (time_of_day ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$')
);
CREATE INDEX medication_schedules_household_seq_idx ON medication_schedules (household_id, server_seq);

-- 通し番号を確定の順に振る（V7）
CREATE TRIGGER medication_schedules_seq BEFORE INSERT OR UPDATE ON medication_schedules
    FOR EACH ROW EXECUTE FUNCTION sync_assign_seq();
