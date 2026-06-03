-- ============================================================
-- MOON CORE — Migration 0003: Chronicle Foundation
-- ============================================================
-- Adds the Chronicle data layer per v0.6a spec.
--
--   chronicles            — one row per Chronicle per operator
--                          (Capital, Creation, Forge, Body, Mind, Machine,
--                           plus any custom Chronicles the operator creates)
--
--   chronicle_entries     — one row per deposit into a Chronicle
--                          Numbered per-Chronicle (entry 1, 2, 3... within Capital).
--                          Encrypted content. Visibility state. Depth score.
--
--   chronicle_amendments  — one row per dated note appended to an entry
--                          Typed: correction | update | later_reflection
--                          Encrypted content.
--
-- The existing `mission` table is PRESERVED. Chronicles is additive.
-- The migration seeds the six starting Chronicles for every existing operator.
-- ============================================================

CREATE TABLE IF NOT EXISTS chronicles (
  id                   INTEGER PRIMARY KEY AUTOINCREMENT,
  operator_id          TEXT NOT NULL,
  slug                 TEXT NOT NULL,            -- 'capital' | 'creation' | 'forge' | 'body' | 'mind' | 'machine' | custom
  title                TEXT NOT NULL,            -- 'Chronicle of Capital', etc. plaintext (not sensitive)
  tonal_lean           TEXT,                     -- e.g. 'cold_analytical' | 'warm_generative' | 'sharp_leverage' | 'direct_unsentimental' | 'patient_exploratory' | 'precise_craft' | 'custom'
  created_at           INTEGER NOT NULL,
  updated_at           INTEGER NOT NULL,
  entry_count          INTEGER NOT NULL DEFAULT 0,
  level                INTEGER NOT NULL DEFAULT 1,
  depth_total          REAL NOT NULL DEFAULT 0,  -- accumulated depth score across all entries
  status               TEXT NOT NULL DEFAULT 'active', -- active | paused | mastered
  metadata_enc         TEXT,                     -- encrypted JSON: custom tonal directives, theme notes, etc.
  FOREIGN KEY (operator_id) REFERENCES operators(operator_id) ON DELETE CASCADE,
  UNIQUE(operator_id, slug)
);
CREATE INDEX IF NOT EXISTS idx_chronicles_op ON chronicles(operator_id);

CREATE TABLE IF NOT EXISTS chronicle_entries (
  id                   INTEGER PRIMARY KEY AUTOINCREMENT,
  operator_id          TEXT NOT NULL,
  chronicle_id         INTEGER NOT NULL,
  entry_number         INTEGER NOT NULL,         -- per-Chronicle sequence (Capital entry 1, Capital entry 2, ...)
  created_at           INTEGER NOT NULL,
  content_enc          TEXT NOT NULL,            -- encrypted entry text (the deposit itself)
  response_enc         TEXT,                     -- encrypted Orion response (if any was given)
  response_movements   TEXT,                     -- plaintext metadata: which of mirror|lesson|forge_stroke fired, e.g. "mirror,forge_stroke" or "full" or "hold"
  depth_score          REAL NOT NULL DEFAULT 0,  -- 0.0–1.0, used for leveling and depth-detection
  visibility           TEXT NOT NULL DEFAULT 'sealed', -- sealed | witness_ready | shared
  recipients_enc       TEXT,                     -- encrypted JSON array of recipient identifiers (only used when visibility=shared)
  word_count           INTEGER NOT NULL DEFAULT 0, -- plaintext, used for depth heuristics and surfaces in lists
  FOREIGN KEY (operator_id) REFERENCES operators(operator_id) ON DELETE CASCADE,
  FOREIGN KEY (chronicle_id) REFERENCES chronicles(id) ON DELETE CASCADE,
  UNIQUE(chronicle_id, entry_number)
);
CREATE INDEX IF NOT EXISTS idx_entries_op_chronicle ON chronicle_entries(operator_id, chronicle_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_entries_op_visibility ON chronicle_entries(operator_id, visibility);

CREATE TABLE IF NOT EXISTS chronicle_amendments (
  id                   INTEGER PRIMARY KEY AUTOINCREMENT,
  operator_id          TEXT NOT NULL,
  entry_id             INTEGER NOT NULL,
  created_at           INTEGER NOT NULL,
  amendment_type       TEXT NOT NULL,            -- 'correction' | 'update' | 'later_reflection'
  content_enc          TEXT NOT NULL,            -- encrypted amendment text
  FOREIGN KEY (operator_id) REFERENCES operators(operator_id) ON DELETE CASCADE,
  FOREIGN KEY (entry_id) REFERENCES chronicle_entries(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_amendments_entry ON chronicle_amendments(entry_id, created_at);
CREATE INDEX IF NOT EXISTS idx_amendments_op_type ON chronicle_amendments(operator_id, amendment_type);

-- ============================================================
-- Seed the six starting Chronicles for every existing operator.
-- New operators get them seeded by the Worker at /awaken.
-- ============================================================
-- We use a deterministic seed strategy: for each operator already in the
-- operators table, insert six chronicle rows if they don't already exist.

INSERT OR IGNORE INTO chronicles (operator_id, slug, title, tonal_lean, created_at, updated_at)
SELECT operator_id, 'capital',  'Chronicle of Capital',  'cold_analytical',     created_at, created_at FROM operators;

INSERT OR IGNORE INTO chronicles (operator_id, slug, title, tonal_lean, created_at, updated_at)
SELECT operator_id, 'creation', 'Chronicle of Creation', 'warm_generative',     created_at, created_at FROM operators;

INSERT OR IGNORE INTO chronicles (operator_id, slug, title, tonal_lean, created_at, updated_at)
SELECT operator_id, 'forge',    'Chronicle of the Forge','sharp_leverage',      created_at, created_at FROM operators;

INSERT OR IGNORE INTO chronicles (operator_id, slug, title, tonal_lean, created_at, updated_at)
SELECT operator_id, 'body',     'Chronicle of the Body', 'direct_unsentimental',created_at, created_at FROM operators;

INSERT OR IGNORE INTO chronicles (operator_id, slug, title, tonal_lean, created_at, updated_at)
SELECT operator_id, 'mind',     'Chronicle of the Mind', 'patient_exploratory', created_at, created_at FROM operators;

INSERT OR IGNORE INTO chronicles (operator_id, slug, title, tonal_lean, created_at, updated_at)
SELECT operator_id, 'machine',  'Chronicle of the Machine','precise_craft',     created_at, created_at FROM operators;
