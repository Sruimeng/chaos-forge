CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS weapons (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id text,
    prompt text NOT NULL,
    model_url text,
    model_path text,
    bug_level real,
    pitch_text text,
    sale_success boolean,
    tripo_task_id text,
    metadata jsonb,
    share_id uuid UNIQUE,
    created_at timestamptz NOT NULL DEFAULT now(),
    shared_at timestamptz
);

CREATE INDEX IF NOT EXISTS weapons_owner_id_idx ON weapons(owner_id);
CREATE INDEX IF NOT EXISTS weapons_created_at_idx ON weapons(created_at);
