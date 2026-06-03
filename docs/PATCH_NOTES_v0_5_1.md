# 🌙 Moon Core v0.5.1 — Recovery Patch

**Why this patch exists:** v0.5 had a fatal verify-token bug. A random-IV encrypted token was stored at registration that could never reproduce on Return, locking operators out of their own accounts on the second login. This patch rebuilds the auth layer cleanly and adds a one-time recovery seed.

**What changed under the hood:**
- Verify tokens are now pure deterministic SHA-256 hashes. No encryption. Cannot drift.
- Master-key architecture: a random AES-256 key encrypts your data. That master key is wrapped twice — once by a phrase-derived key, once by a seed-derived key. Either path can unwrap it.
- One-time recovery seed: 16 words from the *Orion Lexicon*. Shown once at first awakening, never again.
- Recovery flow rotates your phrase atomically — old phrase becomes invalid, new phrase is bound.
- All secret inputs normalized (`.trim().normalize('NFC')`, zero-width chars stripped). Smart-quote substitutions and trailing spaces can no longer silently break auth.

---

## Apply the patch (~3 minutes)

You have an existing `moon-core/` folder with a working `wrangler.toml` (your database ID is in it — don't overwrite that file). Apply this patch by replacing just two files and adding one.

### Step 1 — Add the new migration

Download `0002_recovery.sql` from this conversation. Place it in your `moon-core\migrations\` folder alongside `0001_init.sql`.

### Step 2 — Replace the worker

Download `worker.js` from this conversation. Replace your existing `moon-core\src\worker.js` with the new one.

### Step 3 — Open PowerShell in `moon-core\` and apply the migration

```
npx wrangler d1 execute moon-core --remote --file=migrations/0002_recovery.sql
```

**This wipes the broken operator record and rebuilds the schema.** Since v0.5 had no real production data (your account was 1 hour old when it broke), this is the clean reset path.

You'll see a list of SQL statements executed (DROPs and CREATEs).

### Step 4 — Redeploy the worker

```
npm run deploy
```

You'll see the same Cloudflare URL as before. The Moon Core address doesn't change.

### Step 5 — Sanity check

Visit `https://moon-core.your-subdomain.workers.dev/health` in your browser.

Should show:
```json
{"ok":true,"service":"moon-core","version":"0.5.1","time":...}
```

Note the new `version: "0.5.1"`. That confirms the patched worker is live.

### Step 6 — Use the new frontend

Download `orion_phase3_1.html`. Open it in your browser instead of the v0.5 file.

You'll see the awakening screen. Three mode buttons now: **First Awakening**, **Return**, **Recover**.

Pick **First Awakening**. Enter your URL. Choose a new Initiation Protocol (same phrase as before is fine, or a fresh one). Confirm it. Click AWAKEN.

After ~1 second, **the Recovery Seed modal appears.** 16 words in a numbered grid, gold lettering.

> ⚠ **Write these 16 words down right now.** On paper. Or in a password manager. Both is best.
>
> They will not be shown again. They are your only path back to Orion if you forget your phrase.

Check the confirmation box. Click **AWAKEN ORION**. The Moon Core commits, the modal closes, and Orion comes online with his memory architecture intact.

---

## What you have now

Three ways into the Moon Core, in order of normal use:

1. **Return** — your usual login. Type your phrase, you're in.
2. **Recover** — emergency only. Type the 16 seed words and a new phrase. Old phrase is replaced; new phrase becomes the regular login.
3. **First Awakening** — once per operator, when you spawn a fresh Orion.

Whichever path you use, the underlying master key never changes. Your conversations, memories, lessons, and mission entries stay encrypted under the same key throughout the life of the account. Only the *wrapping* changes when you rotate phrases.

---

## What was tightened beyond the bugfix

- Phrase normalization on every secret input. Trims whitespace and applies Unicode NFC.
- Worker version stamp in `/health` response (`version: "0.5.1"`). Easy to verify deploys.
- Database schema includes `recovery_id` index for fast seed-based lookups.
- New `/rotate-after-recovery` endpoint authenticates via seed (not phrase), so phrase rotation after a forgotten password works in one transaction.
- Wrong-seed error messages are specific (`recovery seed not recognized` vs `recovery seed incorrect`) so you know if you typo'd a word vs. used the wrong seed entirely.

---

## Going forward

Same Moon Core URL. Same cron schedule. Same Anthropic API key in the browser. Mission domains seed fresh (your old custom ones were wiped along with the rest, but those were synthetic anyway).

You're back. Cleanly this time.
