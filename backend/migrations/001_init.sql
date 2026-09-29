-- ============================================================
-- Orbirag — Initial schema (001)
-- Run: psql -U orbirag -d orbirag_db -f migrations/001_init.sql
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- -------------------- USERS --------------------
CREATE TABLE IF NOT EXISTS users (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    firebase_uid TEXT UNIQUE NOT NULL,
    email        TEXT UNIQUE,
    display_name TEXT,
    role         TEXT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_users_firebase_uid ON users(firebase_uid);

-- -------------------- PAPERS --------------------
CREATE TABLE IF NOT EXISTS papers (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title       TEXT NOT NULL,
    authors     TEXT,
    year        TEXT,
    journal     TEXT,
    abstract    TEXT,
    url         TEXT,
    source      TEXT,
    citations   INT DEFAULT 0,
    status      TEXT DEFAULT 'unread'
                CHECK (status IN ('unread','reading','analyzed')),
    progress    REAL DEFAULT 0,
    is_favorite BOOLEAN NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_papers_user_id ON papers(user_id);
CREATE INDEX IF NOT EXISTS idx_papers_user_status ON papers(user_id, status);

-- -------------------- CITATIONS --------------------
CREATE TABLE IF NOT EXISTS citations (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title           TEXT NOT NULL,
    authors         TEXT,
    year            TEXT,
    journal         TEXT,
    style           TEXT,
    source_type     TEXT,
    in_text         TEXT,
    reference_list  TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_citations_user_id ON citations(user_id);

-- -------------------- CHAT --------------------
CREATE TABLE IF NOT EXISTS chat_conversations (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title         TEXT NOT NULL DEFAULT 'New Conversation',
    paper_id      UUID REFERENCES papers(id) ON DELETE SET NULL,
    message_count INT NOT NULL DEFAULT 0,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    archived_at   TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_chat_convs_user
    ON chat_conversations(user_id, updated_at DESC);

CREATE TABLE IF NOT EXISTS chat_messages (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES chat_conversations(id) ON DELETE CASCADE,
    role            TEXT NOT NULL CHECK (role IN ('user','assistant','system')),
    content         TEXT NOT NULL,
    sources         JSONB,
    user_rating     SMALLINT CHECK (user_rating IS NULL OR user_rating IN (-1, 1)),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_chat_msgs_conv
    ON chat_messages(conversation_id, created_at ASC);

CREATE OR REPLACE FUNCTION touch_conversation_on_message()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE chat_conversations
    SET updated_at = NOW(),
        message_count = message_count + 1
    WHERE id = NEW.conversation_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_touch_conversation ON chat_messages;
CREATE TRIGGER trg_touch_conversation
AFTER INSERT ON chat_messages
FOR EACH ROW EXECUTE FUNCTION touch_conversation_on_message();

-- -------------------- SCOPING --------------------
CREATE TABLE IF NOT EXISTS scoping_sessions (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id            UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    raw_topic          TEXT NOT NULL,
    population         TEXT,
    intervention       TEXT,
    comparison         TEXT,
    outcome            TEXT,
    research_question  TEXT,
    status             TEXT NOT NULL DEFAULT 'draft'
                       CHECK (status IN ('draft','completed','searched','archived')),
    current_step       INT NOT NULL DEFAULT 0,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at       TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_scoping_user
    ON scoping_sessions(user_id, status, updated_at DESC);

CREATE OR REPLACE FUNCTION touch_scoping_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_scoping_touch ON scoping_sessions;
CREATE TRIGGER trg_scoping_touch
BEFORE UPDATE ON scoping_sessions
FOR EACH ROW EXECUTE FUNCTION touch_scoping_updated_at();