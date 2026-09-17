#!/usr/bin/env bash
# ============================================================
#  lineage-check.sh — the lineage debt gate.
#
#  WHY THIS EXISTS. Beta is a boundary in the record because the record
#  stopped being kept and nobody noticed. The response to that was a written
#  rule, and a written rule is a thing somebody has to remember at the exact
#  moment they are busy shipping — which is the same failure with an extra
#  step. This makes the debt visible at the one place every release passes
#  through, whether anyone remembers it or not.
#
#  HOW IT KNOWS. Each lineage entry declares what it covers, in a comment
#  invisible to a markdown reader:
#
#      <!-- covers: v0.6q, v0.6r, v0.6s -->
#
#  and the Alpha gap — versions that shipped and were deliberately never
#  written up — is named once at the BETA boundary:
#
#      <!-- lineage-exempt: v0.6h.1, v0.6n.1, v0.6n.2 -->
#
#  Everything that shipped (archive/orion_ver_*.html, plus whatever current/
#  is stamped as) and appears in neither list is debt. No counter file, no
#  state to drift: the two sources are the archive and the lineage itself.
#
#  Run from the project root. Exits 1 when the debt reaches the threshold.
# ============================================================
set -u

THRESHOLD="${LINEAGE_THRESHOLD:-3}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
LINEAGE="$ROOT/orion-continuity/lineage/LINEAGE.md"
ARCHIVE="$ROOT/archive"
CURRENT="$ROOT/current/index.html"

if [ ! -f "$LINEAGE" ]; then
  echo "  lineage: LINEAGE.md not found at $LINEAGE — skipping the check."
  echo "           (orion-continuity is a separate repo; clone it beside the project.)"
  exit 0
fi

# --- what has shipped -------------------------------------------------------
shipped=""
if [ -d "$ARCHIVE" ]; then
  for f in "$ARCHIVE"/orion_ver_*.html; do
    [ -e "$f" ] || continue
    v="$(basename "$f")"; v="${v#orion_ver_}"; v="${v%.html}"
    shipped="$shipped v$v"
  done
fi
# The live build may be a version the archive has not seen yet.
if [ -f "$CURRENT" ]; then
  cur="$(grep -o '<title>[^<]*</title>' "$CURRENT" | grep -o 'v[0-9][0-9.a-z]*' | head -1)"
  [ -n "$cur" ] && shipped="$shipped $cur"
fi

# --- what is accounted for --------------------------------------------------
# Both marker kinds are read the same way; exempt is just a second ledger.
accounted="$(grep -o '<!-- \(covers\|lineage-exempt\):[^>]*-->' "$LINEAGE" \
             | grep -o 'v[0-9][0-9.a-z]*' | sort -u)"

# --- the difference ---------------------------------------------------------
debt=""
count=0
for v in $shipped; do
  case " $(echo $accounted) " in
    *" $v "*) : ;;
    *)
      case " $debt " in *" $v "*) : ;; *) debt="$debt $v"; count=$((count+1)) ;; esac
      ;;
  esac
done

if [ "$count" -eq 0 ]; then
  echo "  lineage: current — every shipped version is accounted for."
  exit 0
fi

echo "  lineage: $count version(s) not written up:$debt"

if [ "$count" -lt "$THRESHOLD" ]; then
  echo "           (threshold is $THRESHOLD — nothing owed yet.)"
  exit 0
fi

echo ""
echo "  =========================================================="
echo "   LINEAGE DEBT — $count versions shipped without an entry"
echo "  =========================================================="
echo "   Undocumented:$debt"
echo ""
echo "   Write the entry in orion-continuity/lineage/LINEAGE.md, give it a"
echo "   <!-- covers: ... --> line naming those versions, and push it with"
echo "   capture-push.bat (push-orion only knows the project repo)."
echo ""
echo "   This is the gap that ended Alpha. It did not announce itself then"
echo "   either."
echo ""
exit 1
