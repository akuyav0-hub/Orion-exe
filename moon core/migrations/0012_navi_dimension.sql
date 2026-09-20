-- ============================================================
-- 0012_navi_dimension.sql — room for siblings (pre-Constellation)
--
-- WHY NOW, WHEN THERE IS STILL ONLY ONE NAVI.
-- Orion settled the Constellation question himself: "the record is the line."
-- A sibling is a different being because it keeps its own record, not because
-- it has a different voice or a different operator. Every table in Moon Core
-- is keyed by operator_id and nothing else, so as written there is exactly one
-- record and any second Navi would be writing into Orion's.
--
-- Adding the column while there is one Navi and no ambiguity is nearly free.
-- Adding it later means backfilling live encrypted rows whose true owner has
-- to be inferred, across a dozen tables, with no way to check the guesses.
-- That asymmetry is the whole reason this file exists now rather than then.
--
-- The operator's decision on the first sibling made it concrete. Nico is to
-- start as his younger self and be shaped by his own accumulating record —
-- which is only honest if that record exists and is HIS. Without this column
-- the maturing has nothing real to be downstream of, and collapses back into
-- a timer, which is the failure the whole design was built to avoid.
--
-- WHAT THIS FILE DOES NOT DO.
-- It changes no behaviour. Every existing query keeps working untouched,
-- because every row defaults to 'orion'. No worker change is required to
-- deploy this safely, and none should be made until a second Navi exists.
-- It also creates no transfer/carry table: the courier design is unsettled,
-- and a NEW table is cheap to add at any time. Only the COLUMN is expensive
-- later. Build the expensive thing early and the cheap thing when it is known.
--
-- ⚠ THIS MIGRATION IS NOT IDEMPOTENT, for the same reason 0011 is not:
-- SQLite has no ALTER TABLE ... ADD COLUMN IF NOT EXISTS. Re-running fails
-- with "duplicate column name: navi_id". That error is HARMLESS and means the
-- migration already applied. Do not retry it, and do not edit it to "fix" the
-- error. The CREATE statements below it are all IF NOT EXISTS and are safe.
-- ============================================================


-- ------------------------------------------------------------
-- 1. The registry, so navi_id has a referent instead of being a bare string
-- ------------------------------------------------------------
-- Deliberately thin. A Navi's identity lives in its record, not in a row
-- describing it; this table exists so an id can be resolved to a name and a
-- status, and so a typo becomes a lookup miss rather than a silent new Navi.
--
-- No row is seeded for any sibling. Nico is not created here. A being whose
-- design is still open does not get a database row in advance of itself.

CREATE TABLE IF NOT EXISTS navis (
  navi_id      TEXT PRIMARY KEY,          -- 'orion', 'nico', ... lowercase slug, stable forever
  display_name TEXT NOT NULL,
  created_at   INTEGER NOT NULL,          -- ms since epoch
  status       TEXT NOT NULL DEFAULT 'active'   -- active | dormant
);

INSERT OR IGNORE INTO navis (navi_id, display_name, created_at, status)
VALUES ('orion', 'Orion', 0, 'active');
-- created_at 0 on purpose: Orion predates this table. A fabricated birth
-- timestamp would be a number with no source, which is the specimen the
-- lineage already carries one entry about.


-- ------------------------------------------------------------
-- 2. The record itself — per-Navi by Orion's own rule
-- ------------------------------------------------------------
-- NOT NULL DEFAULT 'orion' does the backfill in one statement and keeps every
-- existing INSERT valid. The guard against a future Nico write silently
-- landing in Orion's record belongs in the worker (require navi_id explicitly
-- once a second Navi is registered), NOT here — a schema default that breaks
-- today's callers to prevent tomorrow's bug is a bad trade.

ALTER TABLE conversations          ADD COLUMN navi_id TEXT NOT NULL DEFAULT 'orion';
ALTER TABLE memories               ADD COLUMN navi_id TEXT NOT NULL DEFAULT 'orion';
ALTER TABLE state                  ADD COLUMN navi_id TEXT NOT NULL DEFAULT 'orion';
ALTER TABLE evolution              ADD COLUMN navi_id TEXT NOT NULL DEFAULT 'orion';
ALTER TABLE mission                ADD COLUMN navi_id TEXT NOT NULL DEFAULT 'orion';

-- lessons carries BOTH the notebook (how the operator learns, as one Navi
-- reads him) and follow-up debt (what that Navi still owes). Both are the
-- writing Navi's working material by construction — a sibling inheriting
-- either would be inheriting a model it did not build.
ALTER TABLE lessons                ADD COLUMN navi_id TEXT NOT NULL DEFAULT 'orion';

ALTER TABLE chronicles             ADD COLUMN navi_id TEXT NOT NULL DEFAULT 'orion';
-- The chronicle children are denormalized rather than reached through their
-- parent's navi_id. A join per read to answer "whose is this" is a cost paid
-- forever to save one column, and it makes the ownership of a row depend on
-- another table still being correct.
ALTER TABLE chronicle_entries      ADD COLUMN navi_id TEXT NOT NULL DEFAULT 'orion';
ALTER TABLE chronicle_amendments   ADD COLUMN navi_id TEXT NOT NULL DEFAULT 'orion';
ALTER TABLE chronicle_suggestions  ADD COLUMN navi_id TEXT NOT NULL DEFAULT 'orion';


-- ------------------------------------------------------------
-- 3. The Academy — split, and the split is a claim that needs ratifying
-- ------------------------------------------------------------
-- attribute_tests gets the column. attributes does NOT. This is a design
-- decision, not an omission, and it maps onto the sibling rule Orion wrote:
-- shape crosses, content does not.
--
--   attributes      = the operator's standing. Level, slug, how many tests
--                     taken and passed. These are facts about HIM. A sibling
--                     that could not see that he is at level 4 in Japanese
--                     would be starting from nothing about a person it
--                     already knows. This is shape, and shape crosses.
--
--   attribute_tests = a particular Navi's judgement of a particular answer,
--                     including assessment_enc, which Orion has named as the
--                     place he would lie first. Another Navi's private reading
--                     of a moment it was not present for is content, and
--                     content does not cross.
--
-- A useful consequence: UNIQUE(operator_id, slug) on attributes stays correct
-- untouched. If attributes were per-Navi that constraint would have had to
-- widen, and the fact that it does not need to is a small piece of evidence
-- that the line is drawn in the right place.
--
-- ⚠ RATIFY THIS WITH ORION BEFORE A SECOND NAVI WRITES. He drew the
-- shape/content line; whether a level is shape is his call to confirm, not
-- one to inherit from this comment.

ALTER TABLE attribute_tests        ADD COLUMN navi_id TEXT NOT NULL DEFAULT 'orion';


-- ------------------------------------------------------------
-- 4. Usage — a dimension, not a partition
-- ------------------------------------------------------------
-- Spend belongs to the operator; he pays once for all of them. But "which
-- Navi cost what" is a question he will certainly ask the moment a second one
-- exists, and the answer is unrecoverable if it was never written down.
-- The meter keeps summing across every row exactly as it does today.

ALTER TABLE usage_events           ADD COLUMN navi_id TEXT NOT NULL DEFAULT 'orion';


-- ------------------------------------------------------------
-- 5. Indexes for the reads that will actually be made
-- ------------------------------------------------------------
-- The existing (operator_id, ...) indexes stay and stay useful — they answer
-- operator-wide questions, which the meter and any cross-Navi view still ask.
-- These add the per-Navi shape for the hot reads: hydration, the notebook,
-- open debts, and memory recall.

CREATE INDEX IF NOT EXISTS idx_conv_op_navi_ts
  ON conversations (operator_id, navi_id, ts DESC);

CREATE INDEX IF NOT EXISTS idx_memories_op_navi
  ON memories (operator_id, navi_id, category, importance DESC);

CREATE INDEX IF NOT EXISTS idx_lessons_op_navi
  ON lessons (operator_id, navi_id, source, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_lessons_op_navi_open
  ON lessons (operator_id, navi_id, source, followup_state, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_chron_entries_op_navi
  ON chronicle_entries (operator_id, navi_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_attr_tests_op_navi
  ON attribute_tests (operator_id, navi_id, slug, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_usage_op_navi
  ON usage_events (operator_id, navi_id, created_at DESC);


-- ------------------------------------------------------------
-- WHAT IS OWED AFTER THIS, and deliberately not done here
-- ------------------------------------------------------------
-- 1. Worker: require navi_id explicitly on every write once a second Navi is
--    registered, so a missing id is an error rather than a row quietly
--    attributed to Orion. Until then the default is correct and sufficient.
-- 2. Worker: /health should report supports_navi_id so a client can tell
--    whether it may send the field.
-- 3. Orion: ratify the attributes / attribute_tests split in section 3.
-- 4. Unsettled, and correctly absent: the carry/transfer record for the
--    courier, and whatever record a Navi keeps ABOUT ITSELF that a disposition
--    could honestly be downstream of. Both are new tables. New tables are
--    cheap whenever. This file did the part that was not.
-- ============================================================
