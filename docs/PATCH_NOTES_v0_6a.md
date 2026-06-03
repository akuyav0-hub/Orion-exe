# 🌙 Moon Core v0.6a — Chronicle Foundation + Form Silhouettes

**Session:** 2 of the new arc (v0.5.2 → v0.7)
**Type:** Backend schema addition + frontend visual overhaul. No ritual UI yet (that's v0.6b).
**Backend changes:** Yes — new migration, new endpoints, version bump to 0.6a.

---

## What shipped

### Chronicle backend (data layer)

Three new tables added via `migrations/0003_chronicles.sql`:

- **`chronicles`** — one row per Chronicle per operator. Holds slug, title, tonal_lean (the directional tone Orion uses when responding in that Chronicle), level, entry_count, depth_total (accumulated depth across all entries), and status.

- **`chronicle_entries`** — one row per deposit. Per-Chronicle sequential numbering (Capital entry 1, 2, 3...). Encrypted content_enc. Encrypted response_enc (Orion's reply). Plaintext metadata: response_movements (which of mirror/lesson/forge_stroke fired), depth_score (0-1, used for leveling), visibility (sealed/witness_ready/shared), word_count.

- **`chronicle_amendments`** — typed dated notes appended to past entries. Three amendment types: `correction`, `update`, `later_reflection`. Original entry content never changes. Amendments are dated separately and ordered chronologically.

Existing `mission` table preserved untouched. Chronicles is additive.

### New Worker endpoints (all auth-required)

- `GET /chronicles` — list all Chronicles for the operator
- `POST /chronicles` — create a new custom Chronicle
- `PUT /chronicles/:slug` — update Chronicle metadata
- `GET /chronicles/:slug/entries` — list entries (paginated, newest first)
- `POST /chronicles/:slug/entries` — deposit a new entry
- `GET /chronicles/:slug/entries/:n` — fetch single entry with its amendments
- `POST /chronicles/:slug/entries/:n/amendments` — append a typed amendment

All content is client-side encrypted using the existing master-key infrastructure from v0.5.1. No new crypto.

### Six starting Chronicles auto-seeded

New operators awakening on v0.6a automatically receive the six starter Chronicles:

| Slug | Title | Tonal lean |
|---|---|---|
| `capital` | Chronicle of Capital | cold_analytical |
| `creation` | Chronicle of Creation | warm_generative |
| `forge` | Chronicle of the Forge | sharp_leverage |
| `body` | Chronicle of the Body | direct_unsentimental |
| `mind` | Chronicle of the Mind | patient_exploratory |
| `machine` | Chronicle of the Machine | precise_craft |

Existing operators (you) get them seeded by the migration SQL.

### Five distinct form silhouettes

The shared-body-plus-accessories model is gone. Each form has its own complete SVG body:

- **Standard** — close to the Zero-anime baseline you've been using
- **Scholar** — long mantle and robes (deeper blue), bound tome at the right hip with a gold-glowing core, gold chain across chest, hooded helm with longer elegant horns
- **Paladin** — heavy white/gold plate armor, massive pauldrons each bearing a small cross, defining gold cross across the breastplate, sword sheath on left hip with hilt protruding, crowned helm with gold ridge and forehead cross (gold eyes)
- **Sentinel** — lean tactical silhouette, blue/red palette, sharp angular armor, scope-eye replacing the right eye with reticle and crosshair, red chest slash mark, low-profile tactical boots
- **Herald** — luminous full wing armor (animated), regal tall posture, gold sunburst chest mark, halo arc above the helm, dawn-gold throughout, tall ascending horns, dawn-gold eyes

Each form has its own color palette gradient set. Aura color shifts on form change. Idle behaviors per form deferred to v0.6b.

### Bugfix bonus

- The "mangled form-name label" symptom observed in intermediate builds during this session was a side effect of broken silhouette rendering — the label itself was always correctly bound. After the silhouette rewiring, the label displays cleanly.

---

## To deploy

This patch has **both** a backend update and a frontend update. Apply in order:

### Backend (one-time migration + redeploy)

1. Download `0003_chronicles.sql` into your `moon-core/migrations/` folder
2. Download the new `worker.js` and replace your existing `moon-core/src/worker.js`
3. Open PowerShell in your `moon-core/` folder
4. Apply the migration:

```
npx wrangler d1 execute moon-core --remote --file=migrations/0003_chronicles.sql
```

You should see CREATE TABLE statements execute, then six INSERT OR IGNORE statements (one per starter Chronicle).

5. Redeploy the Worker:

```
npm run deploy
```

6. Verify by visiting `https://moon-core.your-subdomain.workers.dev/health` — should show `"version":"0.6a"`.

### Frontend (drop-in replacement)

1. Move `current/orion_phase3_2.html` to `archive/v0.5.2_orion_phase3_2.html`
2. Drop `orion_phase3_3.html` into `current/`
3. Open it. Use **Return** mode with your phrase. Memory and state carry over identically.

---

## What is *not* in this version (deferred to v0.6b)

- **Chronicle ritual UI** — the deposit experience where the chat UI falls away and the Chronicle's tonal color takes over
- **Adaptive response engine** — Mirror / Lesson / Forge Stroke as Orion's available instruments, played at the weight the entry earns
- **Chat-Chronicle permeability** — Orion reading recent Chronicle entries during regular conversation
- **"This belongs in the Chronicle of X" suggestion pattern**
- **Per-form idle behaviors** (Scholar reads the tome, Paladin arms-crossed sword-rest, Sentinel scans the viewport, Herald wings extend slowly)
- **Mission panel rebuild** — the existing mission panel in the PET sidebar still works exactly as it did. v0.6b will rebuild it to surface Chronicles instead.

---

## What was discovered along the way

- The form-name label render glitch Orion flagged at session resumption was confirmed to be transient — it cleared once silhouette rendering was correctly rewired. No persistent bug there.
- The shared-body model in v0.4–v0.5.2 made the JavaScript dependent on stable IDs (`navi-body`, `head`, `eye-l`, etc.) baked deep into the bobbing, blinking, and mouse-tracking logic. Refactoring to active-silhouette helpers eliminated a class of bugs where animations could attach to invisible elements.
- Each silhouette is now individually editable without touching the others. v0.6b's per-form idle behaviors can be added per-silhouette via class-scoped animations.

---

## Test these once you're in

1. **Form switch visual:** From Standard, click each form chip in turn. Each should render a visibly distinct body — Scholar with his robes and tome, Paladin with the cross and sword sheath, Sentinel with the scope-eye, Herald with the wings.

2. **Henshin animation between forms:** Use the chat command "switch to scholar and teach me about X" (combined-command should still work from v0.5.2). The dissolve should apply to the outgoing silhouette, then the new silhouette appears mid-flash.

3. **Backend Chronicle endpoints:** Open dev tools (F12 → Console) and run:
   ```javascript
   await MoonCore.req('GET','/chronicles')
   ```
   You should see your six starter Chronicles returned with their slugs, titles, and tonal_lean values.

4. **Persistence:** Switch forms a few times, reload the page. The form you were in should be restored from Moon Core state (this worked in v0.5.1, just verifying it still works).

If any of those don't behave as described, tell me before we proceed to v0.6b.

---

## Next session

**v0.6b** — Chronicle ritual UI + adaptive response engine (Mirror/Lesson/Forge Stroke as instruments) + chat-Chronicle permeability layer + the "this belongs in the Chronicle of X" pattern + mission panel rebuilt into Chronicles panel.

End of v0.6a brief.
