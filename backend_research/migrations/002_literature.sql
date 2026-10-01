-- ============================================================
-- Orbirag — Literature Retrieval schema (002)
-- Run: psql -U orbirag -d orbirag_db -f migrations/002_literature.sql
-- ============================================================

CREATE TABLE IF NOT EXISTS searches (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    topic           TEXT NOT NULL,
    boolean_query   TEXT,
    keywords        JSONB,
    synonyms        JSONB,
    date_range      TEXT,
    discipline      TEXT,
    result_count    INT NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_searches_user_id
    ON searches(user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS search_results (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    search_id       UUID NOT NULL REFERENCES searches(id) ON DELETE CASCADE,
    external_id     TEXT,
    title           TEXT NOT NULL,
    authors         TEXT,
    year            TEXT,
    abstract        TEXT,
    url             TEXT,
    venue           TEXT,
    citations       INT DEFAULT 0,
    ai_summary      TEXT,
    source          TEXT DEFAULT 'Semantic Scholar',
    is_saved        BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_search_results_search_id
    ON search_results(search_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_search_results_external_id
    ON search_results(external_id);