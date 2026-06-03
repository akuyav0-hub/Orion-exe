-- ============================================================
-- MOON CORE — Migration 0005: Instrument Engine Logging Fields
-- ============================================================
-- Per Orion's v0.6b Session 5 condition (Option B with structured-record requirement):
-- ship Phase 3 raw, but store every deposit with the fields the safety-pass retrofit
-- will need. We tune the safety pass against real observations, not imagination.
--
-- Three additions:
--
--   engine_pick           — plaintext, the instrument the engine selected before
--                           operator override (NULL means no engine pick was made,
--                           e.g. operator chose explicitly without engine input)
--
--   response_raw_enc      — encrypted brain raw output, preserved untouched even
--                           if a safety pass later strips/regenerates response_enc.
--                           For Session 5: response_raw_enc == response_enc at write.
--                           For Session 5.5+: response_enc may diverge after safety
--                           pass; response_raw_enc preserves the original.
--
--   voicing_flag          — 0 default. Set to 1 by safety pass when both attempts
--                           fail validation. Surfaces entries needing manual review.
--
-- response_movements remains the FINAL stored instrument (the operator's last word).
-- engine_pick is the engine's earlier proposal. Both are stored so engine-vs-operator
-- agreement rate can be computed.
-- ============================================================

ALTER TABLE chronicle_entries ADD COLUMN engine_pick TEXT;
ALTER TABLE chronicle_entries ADD COLUMN response_raw_enc TEXT;
ALTER TABLE chronicle_entries ADD COLUMN voicing_flag INTEGER NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_entries_voicing_flag
  ON chronicle_entries(operator_id, voicing_flag)
  WHERE voicing_flag = 1;
