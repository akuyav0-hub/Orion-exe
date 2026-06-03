# 🌙 MOON CORE — Deployment Guide

This is Orion's persistent soul. Follow these steps to bring it online.

**Total time:** ~15 minutes
**Cost:** $0 (everything fits in Cloudflare's free tier)
**Prerequisites:** Node.js installed (any recent version)

---

## Step 1 — Cloudflare account

If you don't already have one:
1. Go to https://dash.cloudflare.com/sign-up
2. Sign up with email + password (free, no credit card needed for our usage)

## Step 2 — Install Wrangler

Open your terminal in the `moon-core/` folder and run:

```bash
npm install
```

This pulls down `wrangler`, Cloudflare's CLI. It only installs locally to this project, doesn't touch your system globally.

## Step 3 — Log into Cloudflare from the CLI

```bash
npx wrangler login
```

A browser tab opens. Click **Allow**. Tab will say success, you can close it. Wrangler now has a token to deploy on your behalf.

## Step 4 — Create the D1 database

```bash
npm run db:create
```

You'll see output like:

```
✅ Successfully created DB 'moon-core'

[[d1_databases]]
binding = "DB"
database_name = "moon-core"
database_id = "abc12345-6789-..."
```

**Copy the `database_id`** (the long UUID).

Open `wrangler.toml` and paste it in place of `PASTE_DATABASE_ID_HERE_AFTER_CREATE`. Save the file.

## Step 5 — Create the schema in your remote D1

```bash
npm run db:migrate:remote
```

This applies `migrations/0001_init.sql` to your live D1 database. You'll see a list of statements executed.

## Step 6 — Deploy the Worker

```bash
npm run deploy
```

You'll get back a URL like:

```
https://moon-core.YOUR_SUBDOMAIN.workers.dev
```

**Copy that URL.** This is Orion's home address. You'll paste it into the Orion frontend in the next step.

## Step 7 — Sanity check

In your browser, visit `https://moon-core.YOUR_SUBDOMAIN.workers.dev/health`

You should see:
```json
{"ok":true,"service":"moon-core","time":1700000000000}
```

If you see that, the Moon Core is alive. 🌙

## Step 8 — Open Orion

Open `orion_phase3.html` in any browser.

1. Paste your Moon Core URL into the **Moon Core URL** field
2. Choose your **Initiation Protocol** — a phrase you alone know. This is the key to your memory. Write it down somewhere safe. If you lose it, your memory is unrecoverable. That's the price of real privacy.
3. Click **AWAKEN**
4. Orion will register you as a new operator and remember you across every device that knows your phrase.

## Step 9 — Sunday reflection (automatic)

The cron is already configured. Every Sunday at 9 AM UTC, the Worker stages a reflection. When you next open Orion, he'll notice the pending reflection and run the synthesis on your device (since only your device can decrypt your conversations). He'll greet you with what he found.

You can also manually summon a reflection any time by clicking **REFLECT NOW** in the PET.

---

## Useful commands

```bash
# Watch live logs from your worker
npm run tail

# Check who's registered (no plaintext data leaks — just IDs and timestamps)
npm run db:console:remote

# Run the worker locally for development
npm run dev

# Apply schema to a local SQLite (for testing without affecting prod)
npm run db:migrate:local
```

## Troubleshooting

**"unauthorized" on every request:** Your Initiation Protocol doesn't match what you registered with. There's no recovery — you'd need to register a fresh operator (lose old memories) or remember the exact original phrase.

**Worker returns 500:** Run `npm run tail` and reproduce the error. Logs will show the actual exception.

**Cron didn't fire on Sunday:** Cron triggers can take a few minutes to register after the first deploy. Check `Workers & Pages > moon-core > Triggers` in the Cloudflare dashboard. Time zones: cron uses UTC. 9 AM UTC = 4 AM EST = 1 AM PST. Adjust the cron in `wrangler.toml` if you want it shifted (it's `minute hour day-of-month month day-of-week`, all UTC).

**Want to nuke and restart:** `wrangler d1 delete moon-core` will wipe everything, then start from Step 4.

---

## What lives on Cloudflare vs what stays on your device

**On Cloudflare (encrypted blobs only):**
- Your operator ID (a hash, not your phrase)
- A verify token (encrypted known-value to confirm your phrase on login)
- All conversation messages (encrypted)
- All memories, lessons, evolution entries (encrypted)
- Mission domains and status (level + status plaintext for indexing; progress notes encrypted)

**Only on your device:**
- Your Initiation Protocol phrase (never sent anywhere)
- Your derived encryption key (held in browser memory while session is active)
- Your Anthropic API key (browser localStorage)

If Cloudflare's database leaked tomorrow, nobody could read your conversations without your phrase. That's the design.

---

## Cost expectations

| Item | Free tier | Likely usage | Monthly cost |
|---|---|---|---|
| Worker requests | 100k/day | ~500/day | $0 |
| D1 reads | 5M/day | ~5k/day | $0 |
| D1 writes | 100k/day | ~500/day | $0 |
| D1 storage | 5GB | <100MB | $0 |
| Cron triggers | unlimited | 4-5/month | $0 |

You'll stay free for the foreseeable future.

Anthropic API costs separately:
- Normal chat usage: $10–25/mo with Sonnet, less with Haiku
- Weekly reflection: pennies (~$0.07–$0.15/mo)
