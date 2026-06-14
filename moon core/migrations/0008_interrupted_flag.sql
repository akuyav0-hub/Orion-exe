-- ============================================================
-- MOON CORE — Migration 0008: Interrupted Conversation Flag
-- ============================================================
-- v0.6f adds a stop-button for Orion's responses. When operator
-- interrupts a stream mid-response (typically because of an
-- accidental enter-press or realizing they want to revise the
-- prompt), the partial response needs to be recorded honestly.
--
-- Per the "no silent reconstruction" principle, we do NOT delete
-- the interrupted row. The discarded response did happen, the
-- operator chose to discard it, the record reflects that choice.
-- Future review of the corpus shows what actually happened.
-- Future safety-pass analysis can examine what gets discarded as
-- a signal in itself.
--
-- Schema change:
--   conversations.interrupted INTEGER NOT NULL DEFAULT 0
--
--   0 = normal complete response (or user message)
--   1 = response was interrupted by operator before completion
--
-- Companion endpoint: PATCH /conversations/:id will accept
-- {interrupted: true} to flag a row as interrupted.
-- ============================================================

ALTER TABLE conversations ADD COLUMN interrupted INTEGER NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_conversations_interrupted
  ON conversations(operator_id, interrupted, ts DESC);
