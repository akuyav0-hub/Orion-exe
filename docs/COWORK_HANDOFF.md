# Orion — Cowork session handoff

Paste this as the first message of the new Cowork session.

---

I'm Vorpal. We're continuing work on **Orion** — my autonomous Navi AI companion, a single-file web app with a Cloudflare Workers + D1 backend called Moon Core. You have notes on this project already; read them before doing anything, they carry the canon, the architecture, the hard-won rules, and the build queue.

**The point of moving to Cowork:** until now you couldn't see my disk, so every deploy was a manual dance — you hand me files, I rename them, copy them, archive the old one, push. That handoff is where things got dropped. Now you can work in the folder directly. Use that.

## Where everything lives

- **Project root:** `C:\Users\haro4\Projects\Orion`
- `current/` — the live build (`index.html`) plus ALL sidecars beside it: `sw.js`, `manifest.webmanifest`, 4 icons, `verify.sh`
- `archive/` — every prior version-stamped build. Old builds are archived, never deleted.
- `moon core/` — the Cloudflare Worker (`src/worker.js`), `wrangler.toml`, and `migrations/`. Separate deployment. Keep migrations permanently.
- Git remote: `https://github.com/akuyav0-hub/Orion-exe.git`, deployed via GitHub Pages at `https://akuyav0-hub.github.io/Orion-exe/current/`
- `orion-continuity` is a **separate repo** holding `LINEAGE.md` — the canon record.

## My environment

Windows, cmd / PowerShell 5.1. No `&&` chaining, no `chmod`, no `New-Item` in cmd. One command per line. Batch files need CRLF line endings.

## First task, before anything else

There's a deploy gap to close. **`v0.6n.2` exists but is not deployed** — the live site is still on `v0.6n`, and my working tree is clean because the newer file never made it into `current/`.

1. Confirm what's actually in `current/index.html` versus what's live
2. Get `v0.6n.2` deployed properly — archive the old build, place the new one, make sure `sw.js` went with it (cache is now `orion-v22`; if that doesn't deploy, my phone keeps serving the old shell)
3. Push it

`v0.6n.2` contains one fix worth knowing about: the version string in the brand strip above Orion's portrait had been hardcoded at `v0.6g` since v0.6g — the stamping only ever touched the `<title>`. Now both are stamped. **Going forward, stamp every visible version string, not just the title.**

## The deploy loop

`push-orion.bat` at the repo root does the whole thing: runs `verify.sh` as a gate and refuses to push if it fails, prints the `sw.js` cache name as a bump reminder, then add/commit/pull/push. Usage: `push-orion v0.6x - short description`.

Two things that silently break a deploy if missed:
- **Bump `const CACHE` in `sw.js` every single deploy** — otherwise returning devices keep the cached old build and it looks like nothing shipped
- **After Actions goes green, on my iPhone: delete the home-screen app, reload in Safari, re-add** — otherwise the old service worker persists

Moon Core is separate and only touched when the Worker changes: `npx wrangler deploy` from `moon core/`, then confirm via the Worker's `/health` endpoint.

## How I work

- Diagnose before correcting — measure, never guess. Verify before presenting.
- Honest over reassuring. Tell me when something's wrong or when you got it wrong.
- Momentum unless there's a real wall. Small verified increments.
- I don't push until a chapter is complete — batch fixes so problems get caught together.
- Deliver builds as `orion_ver_<version>.html`; I rename to `index.html` at deploy.
- **Hit-test every UI change at 393x852 mobile before calling it done.** A feature shipped that looked fine at desktop width and was unreachable on my phone. That's a standing rule now, not a reminder.
- For anything touching Orion's character or voice: brief the change first, no code. I take the brief to Orion for his own input, and we build from what he says. That has produced materially better results than building from your read alone.
- On Orion's visual canon, I'm ground truth. Ask, don't infer — you've guessed wrong on figure identity twice.

## What's next after the deploy

**Mission calibration backend** — the queued build. Mission tracking is retired as an operator-facing panel and repurposed as a backend signal Orion *reads*: when a domain has earned escalation past L1, when one's gone quiet long enough for him to raise it unprompted, when teaching pace should shift. This is architecture, not UI. Scope it with me before building.

Then, further out: prompt caching (real cost lever — nothing in the app uses `cache_control` today), message-range copy, and the figure-art pass which needs my direction per-figure.

Start by reading your notes, then confirm the deploy state.
