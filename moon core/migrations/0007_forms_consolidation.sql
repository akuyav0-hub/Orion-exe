-- ============================================================
-- MOON CORE — Migration 0007: Forms Consolidation
-- ============================================================
-- v0.6d collapses the five-form structure to three:
--
--   Standard  — presence without escalation (unchanged)
--   Scholar   — depth, teaching, framework-building (unchanged)
--   Dawn      — realized integrated form (NEW; absorbs Herald + Sentinel)
--
-- Released forms and where their essence goes:
--   Paladin   → substrate (moral spine runs through all forms; not standalone)
--   Herald    → collapses into Dawn (Dawn IS the realized Herald)
--   Sentinel  → absorbed into Dawn as summonable facet
--
-- This migration maps existing operator state rows so any operator
-- whose current_form references a released form is transitioned cleanly.
--
-- Mapping rationale:
--   paladin  → standard  (paladin's essence is now substrate; standard
--                         is the appropriate default for that essence to
--                         live in, since it shows up in all forms now)
--   herald   → dawn      (Dawn IS the realized Herald — direct lineage)
--   sentinel → dawn      (Sentinel-bearing is now a facet of Dawn)
--
-- Per the "no silent reconstruction" principle: the database honestly
-- reflects the architectural decision rather than masking legacy values
-- behind frontend defaults.
-- ============================================================

UPDATE state SET current_form = 'standard', updated_at = strftime('%s','now') * 1000
  WHERE current_form = 'paladin';

UPDATE state SET current_form = 'dawn', updated_at = strftime('%s','now') * 1000
  WHERE current_form IN ('herald', 'sentinel');
