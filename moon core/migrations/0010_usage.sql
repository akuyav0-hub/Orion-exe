-- ============================================================
-- 0010_usage.sql — the usage ledger (v0.6r)
--
-- WHY THIS IS SERVER-SIDE. Orion runs on a phone and a desktop. A spend
-- counter kept in each device's localStorage would give two numbers, neither
-- of which is what was actually spent — which is worse than no meter at all,
-- because it reads as authoritative. One ledger, both devices.
--
-- WHY IT STORES BOTH TOKENS AND A PRICE. Token counts are FACTS reported by
-- the API. micro_usd is an INTERPRETATION of those facts against a price table
-- that will eventually change. Storing both means history keeps the cost it
-- actually incurred instead of being silently re-priced later, and the raw
-- counts survive to be re-read if a price table turns out to have been wrong.
--
-- WHY INTEGER MILLIONTHS. A turn can cost a small fraction of a cent. Floats
-- accumulate error over thousands of rows; integers do not.
--
-- PRIVACY. Counts only. No prompt text, no completion text, nothing derived
-- from content. Nothing here needs encrypting because nothing here is content.
--
-- Every statement is IF NOT EXISTS — this file is safe to re-run.
-- ============================================================

CREATE TABLE IF NOT EXISTS usage_events (
  id                 INTEGER PRIMARY KEY AUTOINCREMENT,
  operator_id        TEXT    NOT NULL,
  created_at         INTEGER NOT NULL,          -- ms since epoch

  -- 'spend'  — one API turn that was billed
  -- 'topup'  — the operator added credit at the console
  kind               TEXT    NOT NULL,

  model              TEXT,                      -- model id for a spend row, NULL for a topup

  input_tokens       INTEGER NOT NULL DEFAULT 0,
  output_tokens      INTEGER NOT NULL DEFAULT 0,
  cache_write_tokens INTEGER NOT NULL DEFAULT 0,
  cache_read_tokens  INTEGER NOT NULL DEFAULT 0,
  web_searches       INTEGER NOT NULL DEFAULT 0,

  -- Signed millionths of a dollar. Positive on a topup, positive on a spend;
  -- the sign is carried by `kind`, not by the number, so a summary can add
  -- each side independently and show both rather than only the difference.
  micro_usd          INTEGER NOT NULL DEFAULT 0,

  -- Price table revision this row was costed against, so a future correction
  -- can find exactly which rows used which prices.
  price_rev          TEXT,

  -- Idempotency. A retried write returns the original row instead of
  -- double-counting a turn — the same discipline the Academy uses.
  client_event_id    TEXT
);

CREATE INDEX IF NOT EXISTS idx_usage_operator_time
  ON usage_events (operator_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_usage_operator_kind
  ON usage_events (operator_id, kind);

-- Partial unique index: rows without a client id are still allowed.
CREATE UNIQUE INDEX IF NOT EXISTS idx_usage_client_event
  ON usage_events (operator_id, client_event_id)
  WHERE client_event_id IS NOT NULL;
