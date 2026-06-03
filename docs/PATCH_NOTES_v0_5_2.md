# v0.5.2 — Foundation Patch

**Session:** 1 of the new arc (v0.5.2 → v0.7)
**Type:** Bugfix patch. No new features.
**Backend changes:** None. Drop-in HTML replacement only.

---

## What shipped

### Fix 1 — Response truncation eliminated

Per-form `max_tokens` ceilings raised significantly. Length is now governed by bearing in the system prompt, not by the API parameter guillotining replies mid-thought.

| Form | Old cap | New cap | Reasoning |
|---|---|---|---|
| Standard | 400 | **800** | Composed but completes its thoughts |
| Scholar | 900 | **2500** | Real teaching needs real room |
| Paladin | 350 | **700** | Decisive ≠ truncated |
| Sentinel | 500 | **1000** | Complete critiques, never trail off |
| Herald | 500 | **1200** | Full horizons, not half |

Each form's directive now includes an explicit "complete your thought" instruction so length stays *appropriate* even though the ceiling is higher. The system prompt does the voice-shaping; the API parameter just provides headroom.

### Fix 2 — Combined-command parsing

The input handler was returning after a form-match instead of forwarding the residual question to the brain. Messages like *"switch to scholar and teach me about X"* triggered the henshin but dropped the second half.

New parser logic:
1. Detect form-shift phrases anywhere in the message (more flexible patterns than before — `transform/become/shift/switch/enter/change/go to [form]`, also `[form] form/mode`).
2. Strip the matched command + surrounding connectors (and/then/comma/period) from the residual.
3. Trigger the henshin animation.
4. If a residual question remains, wait for the henshin to complete (~1.9s), then send the residual to the brain in the new form.
5. The form-shift's character intro line is suppressed when there's a residual question, so the operator only hears the substantive answer.

**Edge cases handled:**
- Same-form commands ("switch to standard" when already in standard) skip the henshin but still strip the phrase.
- Pure form-switch messages with no residual ("switch to scholar") work exactly as before.
- Sleep/wake commands still terminate (they're whole-message commands; combining with a question doesn't make sense).
- Rename now requires the rename phrase to be at the end of the message (`...your name is X` works; `your name is X and what should I call you` is ambiguous and falls through to chat).

**Verified phrasings that now work:**
- "Switch to scholar and teach me about interface risk"
- "Become paladin, tell me whether I should take this job"
- "Enter sentinel form and find the flaw in my plan"
- "Shift to herald. What's the long game here?"

---

## What was *not* changed

- Backend (worker.js, schema): untouched
- Crypto layer: untouched
- Moon Core API: untouched
- SVG visuals: untouched (silhouettes deferred to v0.6a)
- Form behaviors / system prompts: only the bearing-around-length adjusted, character unchanged
- Chronicle work: not started (begins in v0.6a)

---

## What was discovered along the way

Nothing surfaced beyond the two known issues. Patch was clean and surgical.

One observation worth noting for v0.6: the rename command (`your name is X`) currently terminates the message. If you ever want renaming-plus-conversation in one breath, we'd need to give it the same residual-extraction treatment. Not urgent.

---

## To deploy

This is a frontend-only patch. **No worker redeploy needed. No migration needed.**

1. Download `orion_phase3_2.html` from this conversation.
2. Drop it into your `current/` folder.
3. Move the old `orion_phase3_1.html` to `archive/` (rename to `v0.5.1_orion_phase3_1.html`).
4. Open the new file. Use **Return** mode with your phrase. Memory and state carry over identically.

That's it. The Moon Core URL, your Initiation Protocol, your recovery seed, all conversation history — unchanged.

---

## Next session

**v0.6a** — Chronicle backend (dedicated schema, encryption, mission-to-Chronicle migration, amendment types: correction / update / later_reflection) + form silhouettes (distinct per-form SVG bodies, not shared base + accessories).

End of v0.5.2 brief.
