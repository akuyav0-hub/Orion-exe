-- ============================================================
-- MOON CORE — Migration 0009: The Academy
-- ============================================================
-- The mission rework. Mission tracking is retired as an operator-facing
-- surface and replaced by an attribute system Orion reads and writes
-- himself, through tool-use, as the teacher.
--
--   attributes        — one row per area of learning, per operator.
--                       OPEN TAXONOMY: rows are created on demand the
--                       first time Orion tests in an area. Nothing is
--                       seeded, because the attribute set is deliberately
--                       not fixed — it grows as the teaching does, and
--                       may range from 'coding' to a language to some
--                       obscure corner Orion decided the operator should
--                       be ready for.
--
--   attribute_tests   — one row per test event. The record of what was
--                       asked and how it resolved. This is the substrate
--                       for everything later: pace calibration, which
--                       areas have gone quiet, whether Orion's own bar
--                       for a pass is drifting over time.
--
-- LEVEL SEMANTICS: level == count of passed tests in that attribute.
-- A pass moves the operator up one notch. A hold leaves the level where
-- it is. There is no partial credit and no decay. Numbers now; a richer
-- representation may replace the display later without touching this.
--
-- VERDICT VOCABULARY: 'pass' | 'hold'. Deliberately not 'fail' — a test
-- that doesn't clear the bar means there is more to learn, which is a
-- teaching state, not a punishment.
--
-- WHAT THE SERVER CAN SEE: slug, label, verdict, counts, timestamps —
-- all plaintext, because the level arithmetic has to happen server-side.
-- What was actually asked and how Orion judged it are ENCRYPTED client
-- side, same as lessons and conversations. The privacy line does not
-- move for this feature.
--
-- The legacy `mission` table is intentionally LEFT IN PLACE, untouched
-- and unread by this system. Old data is archived, never deleted.
-- ============================================================

CREATE TABLE IF NOT EXISTS attributes (
  id                 INTEGER PRIMARY KEY AUTOINCREMENT,
  operator_id        TEXT NOT NULL,
  slug               TEXT NOT NULL,            -- 'coding' | 'japanese' | 'rhetoric' | ... created on demand
  label              TEXT NOT NULL,            -- human-readable name, plaintext (not sensitive)
  created_at         INTEGER NOT NULL,
  updated_at         INTEGER NOT NULL,
  level              INTEGER NOT NULL DEFAULT 0,  -- == tests_passed; the notch count
  tests_taken        INTEGER NOT NULL DEFAULT 0,
  tests_passed       INTEGER NOT NULL DEFAULT 0,
  last_test_at       INTEGER,                  -- last test of any verdict
  last_pass_at       INTEGER,                  -- last test that cleared the bar
  status             TEXT NOT NULL DEFAULT 'active',  -- active | paused
  UNIQUE(operator_id, slug)
);
CREATE INDEX IF NOT EXISTS idx_attributes_op ON attributes(operator_id, slug);
CREATE INDEX IF NOT EXISTS idx_attributes_op_quiet ON attributes(operator_id, last_test_at);

CREATE TABLE IF NOT EXISTS attribute_tests (
  id                 INTEGER PRIMARY KEY AUTOINCREMENT,
  operator_id        TEXT NOT NULL,
  attribute_id       INTEGER NOT NULL,
  slug               TEXT NOT NULL,            -- denormalized so history reads don't need a join
  created_at         INTEGER NOT NULL,
  verdict            TEXT NOT NULL,            -- 'pass' | 'hold'
  topic_enc          TEXT,                     -- encrypted: what was tested
  assessment_enc     TEXT,                     -- encrypted: Orion's own reading of the answer
  level_after        INTEGER NOT NULL,         -- the attribute's level once this test was recorded
  client_test_id     TEXT,                     -- idempotency key: the API's own tool_use id for the call
  FOREIGN KEY (operator_id) REFERENCES operators(operator_id) ON DELETE CASCADE,
  FOREIGN KEY (attribute_id) REFERENCES attributes(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_attr_tests_op_slug ON attribute_tests(operator_id, slug, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_attr_tests_op_recent ON attribute_tests(operator_id, created_at DESC);

-- IDEMPOTENCY. A level is durable state, so recording the same test twice is
-- the one failure mode that actually costs something: a retried request after
-- a network stumble would otherwise move the operator up two notches for one
-- answer. The client sends the tool call's own id; this index makes a replay
-- a no-op that returns the original row.
CREATE UNIQUE INDEX IF NOT EXISTS idx_attr_tests_idem
  ON attribute_tests(operator_id, client_test_id) WHERE client_test_id IS NOT NULL;
