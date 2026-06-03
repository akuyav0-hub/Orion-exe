-- ============================================================
-- MOON CORE — Migration 0004: Chronicle Surfacing
-- ============================================================
-- Adds a `surfaced` flag to the chronicles table.
-- Per Orion's v0.6b Session 4 decision: ship 3 Chronicles on day one
-- (Forge, Capital, Machine). Hold Creation/Body/Mind as dormant until
-- the operator chooses to wake them via "+ New Chronicle".
--
-- Dormant Chronicles still exist in the database (rows present, content
-- preserved if any) but are filtered out of the UI's active dropdown.
-- The operator wakes a dormant Chronicle by typing its name into
-- "+ New Chronicle" and confirming the wake prompt.
-- ============================================================

ALTER TABLE chronicles ADD COLUMN surfaced INTEGER NOT NULL DEFAULT 1;

-- Set the day-one shipped Chronicles to surfaced (visible in dropdown)
UPDATE chronicles SET surfaced = 1 WHERE slug IN ('forge', 'capital', 'machine');

-- Set the held-back Chronicles to dormant (seeded but hidden)
UPDATE chronicles SET surfaced = 0 WHERE slug IN ('creation', 'body', 'mind');

CREATE INDEX IF NOT EXISTS idx_chronicles_op_surfaced ON chronicles(operator_id, surfaced);
