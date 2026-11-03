-- DB 設計書（docs/05_db-design.md）の表を作る。
-- 同期する表は共通の列（id・created_at・updated_at・deleted_at・server_seq）を持つ（2章）。
-- 時刻はすべて UTC の timestamptz で持つ（1章）。

-- サーバーが変更を受け取るたびに振る通し番号。表をまたいで1本にし、差分の取得を1つの番号で行う（BR-10）
CREATE SEQUENCE sync_seq;

CREATE TABLE users (
    id            uuid PRIMARY KEY,
    email         text        NOT NULL,
    password_hash text        NOT NULL,
    display_name  text        NOT NULL,
    icon_path     text,
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now(),
    deleted_at    timestamptz,
    server_seq    bigint      NOT NULL DEFAULT nextval('sync_seq')
);
-- メールアドレスは小文字にそろえて保存し、重複を DB でも防ぐ
CREATE UNIQUE INDEX users_email_key ON users (lower(email));

CREATE TABLE user_settings (
    id             uuid PRIMARY KEY,
    user_id        uuid        NOT NULL UNIQUE REFERENCES users (id) ON DELETE CASCADE,
    week_start     text        NOT NULL DEFAULT 'sunday',
    reminder_hours integer              DEFAULT 10,
    notifications  jsonb,
    anomaly_method text        NOT NULL DEFAULT 'statistical',
    created_at     timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now(),
    deleted_at     timestamptz,
    server_seq     bigint      NOT NULL DEFAULT nextval('sync_seq')
);

CREATE TABLE households (
    id         uuid PRIMARY KEY,
    name       text        NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    server_seq bigint      NOT NULL DEFAULT nextval('sync_seq')
);

CREATE TABLE household_members (
    id           uuid PRIMARY KEY,
    household_id uuid        NOT NULL REFERENCES households (id) ON DELETE CASCADE,
    user_id      uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    created_at   timestamptz NOT NULL DEFAULT now(),
    updated_at   timestamptz NOT NULL DEFAULT now(),
    deleted_at   timestamptz,
    server_seq   bigint      NOT NULL DEFAULT nextval('sync_seq')
);
-- 抜けた人がもう一度入れるよう、一意にするのは有効な行（deleted_at が空）だけ
CREATE UNIQUE INDEX household_members_active_key
    ON household_members (household_id, user_id) WHERE deleted_at IS NULL;

CREATE TABLE cats (
    id                 uuid PRIMARY KEY,
    household_id       uuid        NOT NULL REFERENCES households (id) ON DELETE CASCADE,
    name               text        NOT NULL,
    birth_date         date,
    sex                text,
    conditions         text,
    icon_path          text,
    status             text        NOT NULL DEFAULT 'active',
    anomaly_thresholds jsonb,
    created_at         timestamptz NOT NULL DEFAULT now(),
    updated_at         timestamptz NOT NULL DEFAULT now(),
    deleted_at         timestamptz,
    server_seq         bigint      NOT NULL DEFAULT nextval('sync_seq'),
    CONSTRAINT cats_status_check CHECK (status IN ('active', 'farewell'))
);

CREATE TABLE record_types (
    id           uuid PRIMARY KEY,
    household_id uuid        NOT NULL REFERENCES households (id) ON DELETE CASCADE,
    name         text        NOT NULL,
    icon         text,
    kind         text        NOT NULL,
    sort_order   integer,
    hidden       boolean     NOT NULL DEFAULT false,
    created_at   timestamptz NOT NULL DEFAULT now(),
    updated_at   timestamptz NOT NULL DEFAULT now(),
    deleted_at   timestamptz,
    server_seq   bigint      NOT NULL DEFAULT nextval('sync_seq'),
    CONSTRAINT record_types_kind_check CHECK (kind IN
        ('food', 'water', 'medicine', 'urine', 'stool', 'vomit', 'weight', 'brushing', 'custom'))
);

CREATE TABLE records (
    id             uuid PRIMARY KEY,
    cat_id         uuid        NOT NULL REFERENCES cats (id) ON DELETE CASCADE,
    record_type_id uuid        NOT NULL REFERENCES record_types (id) ON DELETE CASCADE,
    recorded_at    timestamptz NOT NULL,
    -- 退会しても記録を残せるよう、ユーザーが消えたら空にする（BR-17）
    author_id      uuid                 REFERENCES users (id) ON DELETE SET NULL,
    author_name    text        NOT NULL,
    value_number   numeric,
    level          text,
    detail         jsonb,
    memo           text,
    created_at     timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now(),
    deleted_at     timestamptz,
    server_seq     bigint      NOT NULL DEFAULT nextval('sync_seq'),
    CONSTRAINT records_level_check CHECK (level IS NULL OR level IN ('little', 'normal', 'much'))
);
CREATE INDEX records_cat_recorded_at_idx ON records (cat_id, recorded_at);

CREATE TABLE record_photos (
    id         uuid PRIMARY KEY,
    record_id  uuid        NOT NULL REFERENCES records (id) ON DELETE CASCADE,
    file_path  text        NOT NULL,
    size_bytes integer,
    sort_order integer     NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    server_seq bigint      NOT NULL DEFAULT nextval('sync_seq'),
    -- 1つの記録に3枚まで（データ要件）
    CONSTRAINT record_photos_sort_order_check CHECK (sort_order BETWEEN 1 AND 3)
);

CREATE TABLE widget_buttons (
    id             uuid PRIMARY KEY,
    user_id        uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    record_type_id uuid        NOT NULL REFERENCES record_types (id) ON DELETE CASCADE,
    sort_order     integer,
    created_at     timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now(),
    deleted_at     timestamptz,
    server_seq     bigint      NOT NULL DEFAULT nextval('sync_seq')
);

-- ここから下はサーバーだけの表（5章）。トークンは平文で持たず、ハッシュだけを保存する
CREATE TABLE invitations (
    id           uuid PRIMARY KEY,
    household_id uuid        NOT NULL REFERENCES households (id) ON DELETE CASCADE,
    token_hash   text        NOT NULL UNIQUE,
    expires_at   timestamptz NOT NULL,
    used_at      timestamptz
);

CREATE TABLE refresh_tokens (
    id         uuid PRIMARY KEY,
    user_id    uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    token_hash text        NOT NULL UNIQUE,
    expires_at timestamptz NOT NULL,
    revoked_at timestamptz
);
CREATE INDEX refresh_tokens_user_idx ON refresh_tokens (user_id);
