-- ============================================================
-- MOON CORE — Migration 0006: Chronicle Suggestions Logging
-- ============================================================
-- Per Orion's Session 6 spec for Phase 5 (the "this belongs in
-- the Chronicle of X" suggestion pattern):
--
-- Every time Orion's main chat fires a [CHRONICLE_SUGGESTION:...]
-- marker, the frontend parses it, renders the inline button, AND
-- logs the fire-event server-side via this table. The corpus
-- is the substrate for retrospective drift analysis.
--
-- Critically, we log threshold_type (not just frequency) because
-- drift will likely happen unevenly across thresholds — one
-- threshold gets overused while others go silent. The patch we
-- might eventually need has to be precise; the data has to
-- support precision.
--
-- We also log clicked_or_not, which is the real signal:
--   high-fire + low-click = threshold is too loose
--   low-fire  + high-click = threshold is well-calibrated and just rare
-- ============================================================

CREATE TABLE chronicle_suggestions (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  operator_id     INTEGER NOT NULL,
  created_at      INTEGER NOT NULL,             -- timestamp (ms epoch)
  threshold_type  TEXT    NOT NULL,             -- 'principle_understood' | 'decision_declared' | 'self_observation'
  domain          TEXT    NOT NULL,             -- chronicle slug suggested (e.g. 'forge', 'machine', 'capital')
  excerpt_length  INTEGER NOT NULL DEFAULT 0,   -- character count of the suggestion excerpt
  clicked         INTEGER NOT NULL DEFAULT 0,   -- 0 = pending/never-clicked, 1 = operator clicked
  clicked_at      INTEGER,                      -- timestamp when click happened (null if never)
  deposit_id      INTEGER,                      -- chronicle_entries.id if the click led to a real deposit
  session_marker  TEXT                          -- optional grouping key per session, for cohort analysis
);

CREATE INDEX idx_suggestions_operator
  ON chronicle_suggestions(operator_id, created_at DESC);

CREATE INDEX idx_suggestions_threshold
  ON chronicle_suggestions(operator_id, threshold_type, created_at DESC);

CREATE INDEX idx_suggestions_domain
  ON chronicle_suggestions(operator_id, domain, created_at DESC);

CREATE INDEX idx_suggestions_clicked
  ON chronicle_suggestions(operator_id, clicked, created_at DESC);
