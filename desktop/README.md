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

1. opens from a taskbar icon, no browser  — **milestone 1**
2. tray icon reading READY, click to show and hide
3. a global hotkey summons him from anything
4. the API key encrypted at rest, unlocked by the Initiation Protocol phrase
5. Moon Core works exactly as it does today — **milestone 1**
6. closing the window does not kill him; quitting from the tray does

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
