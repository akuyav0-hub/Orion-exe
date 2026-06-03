-- ============================================================
-- MOON CORE — Migration 0002: Recovery & Auth Patch
-- ============================================================
-- v0.5 had a fatal verify-token bug (random-IV encrypted token
-- never reproduced on Return). This migration wipes and rebuilds
-- with a clean master-key architecture:
--
--   - verify_token_phrase / verify_token_seed: pure SHA-256
--     deterministic hashes. No encryption. Reproducible.
--
--   - wrapped_key_phrase / wrapped_key_seed: the master key
--     encrypted twice. Either the phrase OR the seed can unwrap
--     it. The seed enables one-time recovery.
--
--   - recovery_id: public index for /recover lookups when the
--     user doesn't know their operator_id.
--
-- Because v0.5 had ~0 production data, this migration drops
-- everything and rebuilds clean.
-- ============================================================

DROP TABLE IF EXISTS evolution;
DROP TABLE IF EXISTS state;
DROP TABLE IF EXISTS mission;
DROP TABLE IF EXISTS lessons;
DROP TABLE IF EXISTS memories;
DROP TABLE IF EXISTS conversations;
DROP TABLE IF EXISTS operators;

CREATE TABLE operators (
  operator_id          TEXT PRIMARY KEY,
  recovery_id          TEXT NOT NULL UNIQUE,
  created_at           INTEGER NOT NULL,
  last_seen_at         INTEGER NOT NULL,
  display_name_enc     TEXT,
  metadata_enc         TEXT,
  verify_token_phrase  TEXT NOT NULL,
  verify_token_seed    TEXT NOT NULL,
  wrapped_key_phrase   TEXT NOT NULL,
  wrapped_key_seed     TEXT NOT NULL
);
CREATE INDEX idx_operators_recovery ON operators(recovery_id);

CREATE TABLE conversations (
  id                 INTEGER PRIMARY KEY AUTOINCREMENT,
  operator_id        TEXT NOT NULL,
  ts                 INTEGER NOT NULL,
  role               TEXT NOT NULL,
  content_enc        TEXT NOT NULL,
  form               TEXT,
  topics_enc         TEXT,
  FOREIGN KEY (operator_id) REFERENCES operators(operator_id) ON DELETE CASCADE
);
CREATE INDEX idx_conversations_op_ts ON conversations(operator_id, ts);

CREATE TABLE memories (
  id                 INTEGER PRIMARY KEY AUTOINCREMENT,
  operator_id        TEXT NOT NULL,
  created_at         INTEGER NOT NULL,
  last_accessed_at   INTEGER NOT NULL,
  category           TEXT NOT NULL,
  content_enc        TEXT NOT NULL,
  importance         INTEGER NOT NULL DEFAULT 5,
  decay              INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY (operator_id) REFERENCES operators(operator_id) ON DELETE CASCADE
);
CREATE INDEX idx_memories_op_cat ON memories(operator_id, category);
CREATE INDEX idx_memories_op_imp ON memories(operator_id, importance DESC);

CREATE TABLE lessons (
  id                 INTEGER PRIMARY KEY AUTOINCREMENT,
  operator_id        TEXT NOT NULL,
  created_at         INTEGER NOT NULL,
  domain             TEXT NOT NULL,
  title_enc          TEXT NOT NULL,
  content_enc        TEXT NOT NULL,
  source             TEXT NOT NULL,
  followup_due       INTEGER,
  FOREIGN KEY (operator_id) REFERENCES operators(operator_id) ON DELETE CASCADE
);
CREATE INDEX idx_lessons_op_dom ON lessons(operator_id, domain);
CREATE INDEX idx_lessons_op_followup ON lessons(operator_id, followup_due);

CREATE TABLE mission (
  id                 INTEGER PRIMARY KEY AUTOINCREMENT,
  operator_id        TEXT NOT NULL,
  domain             TEXT NOT NULL,
  updated_at         INTEGER NOT NULL,
  level              INTEGER NOT NULL DEFAULT 1,
  progress_enc       TEXT,
  status             TEXT NOT NULL DEFAULT 'active',
  FOREIGN KEY (operator_id) REFERENCES operators(operator_id) ON DELETE CASCADE,
  UNIQUE(operator_id, domain)
);
CREATE INDEX idx_mission_op ON mission(operator_id);

CREATE TABLE state (
  operator_id        TEXT PRIMARY KEY,
  updated_at         INTEGER NOT NULL,
  navi_name          TEXT NOT NULL DEFAULT 'ORION',
  current_form       TEXT NOT NULL DEFAULT 'standard',
  sync_value         REAL NOT NULL DEFAULT 12,
  total_interactions INTEGER NOT NULL DEFAULT 0,
  preferred_model    TEXT NOT NULL DEFAULT 'claude-sonnet-4-6',
  settings_enc       TEXT,
  FOREIGN KEY (operator_id) REFERENCES operators(operator_id) ON DELETE CASCADE
);

CREATE TABLE evolution (
  id                 INTEGER PRIMARY KEY AUTOINCREMENT,
  operator_id        TEXT NOT NULL,
  created_at         INTEGER NOT NULL,
  trigger_type       TEXT NOT NULL,
  theme              TEXT NOT NULL,
  theme_enc          TEXT,
  content_enc        TEXT NOT NULL,
  surfaced_at        INTEGER,
  acknowledged       INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY (operator_id) REFERENCES operators(operator_id) ON DELETE CASCADE
);
CREATE INDEX idx_evolution_op_ack ON evolution(operator_id, acknowledged, created_at DESC);
