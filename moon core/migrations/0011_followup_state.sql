-- ============================================================
-- 0011_followup_state.sql — closing a debt (v0.6s)
--
-- WHY. v0.6r gave Orion a way to record what he owes and a way to read it
-- back, and no way to ever retire one. He found the gap himself when asked
-- what happens to a debt that goes stale: "I'd have to reconstruct what I even
-- meant by it... the honest move is to either refresh the debt with a sharper,
-- current version, or admit it's no longer relevant and let it go, rather than
-- let a fossil sit in the record pretending to be live."
--
-- Without a close, `check_followups` could only ever grow, and a list that only
-- grows stops being read — which would have quietly killed the mechanism.
--
-- STATE, NOT DELETION. A closed debt stays in the record. What was owed and
-- whether it was taught or abandoned is exactly the kind of thing the record
-- exists to hold; deleting it would leave a teacher unable to see that he let
-- something go.
--
-- ⚠ THIS MIGRATION IS NOT IDEMPOTENT, and cannot be made so: SQLite has no
-- ALTER TABLE ... ADD COLUMN IF NOT EXISTS. Running it twice fails with
-- "duplicate column name: followup_state". That error is HARMLESS and means
-- the migration has already been applied — it is not a reason to retry, and
-- nothing else in this file runs before it.
-- ============================================================

ALTER TABLE lessons ADD COLUMN followup_state TEXT;
ALTER TABLE lessons ADD COLUMN followup_closed_at INTEGER;

-- Open debts are the common read: state IS NULL means still owed.
CREATE INDEX IF NOT EXISTS idx_lessons_followup_open
  ON lessons (operator_id, source, followup_state, created_at DESC);
