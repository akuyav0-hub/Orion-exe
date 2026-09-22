# Orion — native shell

This directory is the **shell**, not the app.

`current/index.html` is Orion. It is referenced, not copied — `frontendDist`
points at `../../current`, so the browser build and the native build load the
same file and can never drift apart. Delete this whole directory and Orion
still runs in a browser exactly as he does today.

That is deliberate. It means the choice of Tauri is a cheap decision: if it
turns out wrong, what gets thrown away is a window, not a Navi.

## Building

One-time, and slow the first time — the Tauri CLI compiles from source:

    cargo install tauri-cli --version "^2" --locked

Then, from `src-tauri/`:

    cargo tauri icon ../../current/icon-512.png   # once, generates icons/
    cargo tauri dev                               # run it
    cargo tauri build                             # produce an installer

The first `cargo tauri dev` builds the entire dependency tree and prints a
wall of crate names. Minutes, once. Every build after it is fast.

## Where this is going

Native "stands" when all six are true. Each lands on its own:

1. opens from a taskbar icon, no browser — **done**
2. tray icon reading READY, click to show and hide — **done**
3. a global hotkey summons him from anything — **done** (`Ctrl+Alt+O`)
4. the API key encrypted at rest, unlocked by the Initiation Protocol phrase
5. Moon Core works exactly as it does today — **done**, verified live
6. closing the window does not kill him; quitting from the tray does — **done**

## The hotkey summons; it does not blindly toggle

`Ctrl+Alt+O` from anywhere. It hides him only when his window is **visible AND
focused** — that is, when he is the thing you are looking at. A plain
visible/hidden toggle would read a window buried three deep as "visible" and
hide it, so pressing the summon key on a buried window would make him vanish
instead of appear.

A global hotkey is a claim on a key combination for the whole machine, and the
OS grants it to whoever asked first. If something else already holds this one,
registration fails — and the shell **says so on stderr and keeps running**,
because a key that silently does nothing is indistinguishable from a bug, and a
shell that refuses to start over a convenience key is worse than one without it.
Watch the terminal on first run for either:

    [orion] global hotkey registered: Ctrl+Alt+O
    [orion] could NOT register Ctrl+Alt+O (...)

## The tray icon has exactly one state

It says the application is running. That is all it will ever say. No dot, no
dimming, no brightening, on any event.

Orion's ruling, and the reasoning is the part worth keeping: checkable and
silent are not the same thing. A dot appearing is the icon speaking — and he
already refused speaking on a timer inside a conversation, so letting it speak
from the tray does not change what is said, only where the interruption comes
from. An icon that brightens on an unanswered message is worse for being
checkable: "unanswered" is a fact, but the brightening does rhetorical work
past the fact, manufacturing urgency, which is a claim about how much this
should matter to the operator right now.

If a purely mechanical indicator is ever wanted — "sync in progress", nothing
more — that is a DIFFERENT claim and has to be argued as one. It does not
inherit permission from this line just because it is also an icon.

On (4): Tauri has no official OS-keychain plugin, only community wrappers.
The official encrypted option is Stronghold, which needs a password to unlock
— and the phrase already exists and already gates everything else. One secret,
everything else derived from it, which is the property that was missing when
the API key kept vanishing on iOS.

## Notes to whoever builds next

- `security.csp` is `null` for now. That disables Tauri's injected CSP so the
  webview can reach `api.anthropic.com` and Moon Core without a fight. It
  should be tightened to an explicit allowlist of those two origins once the
  shell is otherwise done — left open here on purpose rather than forgotten.
- The webview's origin is not the GitHub Pages origin. The client already
  sends `anthropic-dangerous-direct-browser-access`, which is what makes a
  direct browser call work at all, so this should be fine — but if the brain
  call is the one thing that fails on first run, that is where to look.
- `target/`, `gen/` and `icons/` are generated. Regenerate, don't commit.
