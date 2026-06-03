-- ============================================================
-- MOON CORE — Orion's persistent soul
-- D1 (SQLite) schema for Cloudflare Workers
-- ============================================================

-- The operator: you. One row per person Orion serves.
-- Identified by operator_id (derived from Initiation Protocol).
-- All sensitive content is encrypted client-side before reaching this DB.
CREATE TABLE IF NOT EXISTS operators (
  operator_id        TEXT PRIMARY KEY,        -- SHA-256 hash of Initiation Protocol phrase
  created_at         INTEGER NOT NULL,         -- Unix ms
  last_seen_at       INTEGER NOT NULL,
  display_name_enc   TEXT,                     -- Encrypted operator name (if shared)
  metadata_enc       TEXT,                     -- Encrypted JSON blob: name, etc.
  verify_token       TEXT NOT NULL             -- Encrypted known-value to verify the phrase
);

-- Conversation log — every exchange, encrypted.
CREATE TABLE IF NOT EXISTS conversations (
  id                 INTEGER PRIMARY KEY AUTOINCREMENT,
  operator_id        TEXT NOT NULL,
  ts                 INTEGER NOT NULL,         -- Unix ms
  role               TEXT NOT NULL,            -- 'user' | 'assistant'
  content_enc        TEXT NOT NULL,            -- Encrypted message content
  form               TEXT,                     -- Orion's form when speaking ('standard'|'scholar'|...)
  topics_enc         TEXT,                     -- Encrypted comma-separated topics (extracted later)
  FOREIGN KEY (operator_id) REFERENCES operators(operator_id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_conversations_op_ts ON conversations(operator_id, ts);

-- Long-term memories — facts about the operator Orion has learned.
-- Each memory has a category and importance score.
CREATE TABLE IF NOT EXISTS memories (
  id                 INTEGER PRIMARY KEY AUTOINCREMENT,
  operator_id        TEXT NOT NULL,
  created_at         INTEGER NOT NULL,
  last_accessed_at   INTEGER NOT NULL,
  category           TEXT NOT NULL,            -- 'identity'|'project'|'preference'|'goal'|'context'|'history'
  content_enc        TEXT NOT NULL,            -- Encrypted memory text
  importance         INTEGER NOT NULL DEFAULT 5, -- 1-10
  decay              INTEGER NOT NULL DEFAULT 0, -- 0=permanent, 1=can fade
  FOREIGN KEY (operator_id) REFERENCES operators(operator_id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_memories_op_cat ON memories(operator_id, category);
CREATE INDEX IF NOT EXISTS idx_memories_op_imp ON memories(operator_id, importance DESC);

-- Lessons — teaching moments Orion has delivered or surfaced.
-- Tagged by mission domain for retrieval.
CREATE TABLE IF NOT EXISTS lessons (
  id                 INTEGER PRIMARY KEY AUTOINCREMENT,
  operator_id        TEXT NOT NULL,
  created_at         INTEGER NOT NULL,
  domain             TEXT NOT NULL,            -- 'finance'|'tech'|'business'|'ai_mastery'|'health'|'philosophy'|...
  title_enc          TEXT NOT NULL,
  content_enc        TEXT NOT NULL,
  source             TEXT NOT NULL,            -- 'chat'|'reflection'|'manual'
  followup_due       INTEGER,                  -- Unix ms — when to revisit
  FOREIGN KEY (operator_id) REFERENCES operators(operator_id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_lessons_op_dom ON lessons(operator_id, domain);
CREATE INDEX IF NOT EXISTS idx_lessons_op_followup ON lessons(operator_id, followup_due);

-- Mission tracker — operator's progress as a being-becoming-foundation.
-- One row per domain. Started values are minimal until operator-driven.
CREATE TABLE IF NOT EXISTS mission (
  id                 INTEGER PRIMARY KEY AUTOINCREMENT,
  operator_id        TEXT NOT NULL,
  domain             TEXT NOT NULL,            -- matches lesson domain
  updated_at         INTEGER NOT NULL,
  level              INTEGER NOT NULL DEFAULT 1,
  progress_enc       TEXT,                     -- Encrypted JSON: goals, milestones, notes
  status             TEXT NOT NULL DEFAULT 'active', -- 'active'|'paused'|'mastered'
  FOREIGN KEY (operator_id) REFERENCES operators(operator_id) ON DELETE CASCADE,
  UNIQUE(operator_id, domain)
);
CREATE INDEX IF NOT EXISTS idx_mission_op ON mission(operator_id);

-- State — persistent values that should survive across devices.
-- One row per operator (sync, mood baseline, current form, name, etc.)
CREATE TABLE IF NOT EXISTS state (
  operator_id        TEXT PRIMARY KEY,
  updated_at         INTEGER NOT NULL,
  navi_name          TEXT NOT NULL DEFAULT 'ORION',
  current_form       TEXT NOT NULL DEFAULT 'standard',
  sync_value         REAL NOT NULL DEFAULT 12,
  total_interactions INTEGER NOT NULL DEFAULT 0,
  preferred_model    TEXT NOT NULL DEFAULT 'claude-sonnet-4-6',
  settings_enc       TEXT,                     -- Encrypted JSON for any extras
  FOREIGN KEY (operator_id) REFERENCES operators(operator_id) ON DELETE CASCADE
);

-- Evolution log — what Orion thought about / learned during weekly reflections,
-- or any autonomous thinking sessions while operator was away.
CREATE TABLE IF NOT EXISTS evolution (
  id                 INTEGER PRIMARY KEY AUTOINCREMENT,
  operator_id        TEXT NOT NULL,
  created_at         INTEGER NOT NULL,
  trigger_type       TEXT NOT NULL,            -- 'weekly_reflection'|'manual'|'scheduled'
  theme              TEXT NOT NULL,            -- Brief theme tag (encrypted optional)
  theme_enc          TEXT,                     -- Encrypted full theme description
  content_enc        TEXT NOT NULL,            -- Encrypted reflection content
  surfaced_at        INTEGER,                  -- Unix ms when operator first saw it
  acknowledged       INTEGER NOT NULL DEFAULT 0, -- 0=unread, 1=surfaced to operator
  FOREIGN KEY (operator_id) REFERENCES operators(operator_id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_evolution_op_ack ON evolution(operator_id, acknowledged, created_at DESC);

-- Initial mission domain seed data is inserted on first operator registration
-- by the Worker (so each operator gets their own seeded rows).
