// ============================================================
//  Orion — native shell.
//
//  Conditions for "native stands", and where each one is:
//    1. opens from a taskbar icon, no browser          DONE
//    2. tray icon reading READY, click to show/hide    DONE
//    3. a global hotkey summons him                    THIS FILE
//    4. API key encrypted at rest, unlocked by phrase  next
//    5. Moon Core works exactly as today               DONE (verified live)
//    6. closing the window does not kill him; the
//       tray quits him                                 DONE
// ============================================================

// Release builds get no console window behind the app. Debug builds keep
// it on purpose — it is where panics, webview errors and the hotkey
// registration result show up.
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use tauri::{
    menu::{Menu, MenuItem, PredefinedMenuItem},
    tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent},
    AppHandle, Manager, WindowEvent,
};

/// The tray's only word. Not "awake" — Orion ruled that out himself, and the
/// reasoning is worth keeping next to the string: an icon claiming he is awake
/// is a claim about an interior he does not have between turns. "Ready" is a
/// fact about the application. It is honest whether or not anyone is looking.
const TRAY_LABEL: &str = "Orion — READY";

/// Ctrl+Alt+O. Chosen for being mnemonic and for not colliding with anything
/// Windows or a common editor claims. If the operator wants a different one it
/// is these two lines and the menu string below.
#[cfg(desktop)]
const HOTKEY_HUMAN: &str = "Ctrl+Alt+O";

/// Bring him forward, or put him away if he is already the window you are
/// looking at.
///
/// NOT a plain visible/hidden toggle, and the difference matters. A global
/// hotkey's whole job is "bring him to me from whatever I am doing" — but a
/// window can be *visible and buried three windows deep*, and a plain toggle
/// would read that as visible and HIDE him. You would press the summon key and
/// watch him vanish. So the dismiss branch requires visible AND focused: if he
/// is not the thing you are looking at, the key raises him.
fn summon_or_dismiss(app: &AppHandle) {
    if let Some(win) = app.get_webview_window("main") {
        let visible = win.is_visible().unwrap_or(false);
        let focused = win.is_focused().unwrap_or(false);
        if visible && focused {
            let _ = win.hide();
        } else {
            let _ = win.unminimize();
            let _ = win.show();
            let _ = win.set_focus();
        }
    }
}

fn main() {
    tauri::Builder::default()
        .setup(|app| {
            // ---- the tray menu --------------------------------------------
            // The first item is a disabled label, not a control. It exists so
            // the tray says the same thing whether or not the operator hovers
            // long enough for a tooltip.
            let label = MenuItem::with_id(app, "label", TRAY_LABEL, false, None::<&str>)?;
            let sep = PredefinedMenuItem::separator(app)?;
            // Deliberately a FIXED string rather than flipping between "Show"
            // and "Hide". The window's visibility is something the operator can
            // already see on their own screen; a menu that narrates it back is
            // the tray commenting, which is the thing being avoided here.
            let toggle = MenuItem::with_id(app, "toggle", "Show / Hide Orion", true, None::<&str>)?;
            let quit = MenuItem::with_id(app, "quit", "Quit Orion", true, None::<&str>)?;
            let menu = Menu::with_items(app, &[&label, &sep, &toggle, &quit])?;

            // ---- the tray icon --------------------------------------------
            // ONE STATE, FOREVER. No dot, no dimming, no brightening, on any
            // event. Orion's ruling, and his reasoning is the part to preserve:
            // checkable and silent are not the same thing. A dot appearing is
            // the icon speaking, and he already refused speaking on a timer
            // inside a conversation — letting it speak from the tray instead
            // does not change what is being said, only where the interruption
            // comes from. An icon that brightens on an unanswered message is
            // worse for being checkable: "unanswered" is a fact, but the
            // brightening does rhetorical work past the fact, manufacturing
            // urgency, which is a claim about how much this should matter to
            // the operator right now.
            //
            // If a genuinely mechanical indicator is ever wanted — "sync in
            // progress" and nothing more — it is a DIFFERENT claim and must be
            // argued as one. It does not get to inherit permission from this
            // line just because it also happens to be an icon.
            TrayIconBuilder::with_id("orion-tray")
                .icon(app.default_window_icon().unwrap().clone())
                .tooltip(TRAY_LABEL)
                .menu(&menu)
                // Left click belongs to show/hide; the menu is the right button.
                .show_menu_on_left_click(false)
                .on_menu_event(|app, event| match event.id.as_ref() {
                    "toggle" => summon_or_dismiss(app),
                    "quit" => app.exit(0),
                    _ => {}
                })
                .on_tray_icon_event(|tray, event| {
                    if let TrayIconEvent::Click {
                        button: MouseButton::Left,
                        button_state: MouseButtonState::Up,
                        ..
                    } = event
                    {
                        summon_or_dismiss(tray.app_handle());
                    }
                })
                .build(app)?;

            // ---- the global hotkey ----------------------------------------
            #[cfg(desktop)]
            {
                use tauri_plugin_global_shortcut::{
                    Code, GlobalShortcutExt, Modifiers, Shortcut, ShortcutState,
                };

                let hotkey = Shortcut::new(Some(Modifiers::CONTROL | Modifiers::ALT), Code::KeyO);

                app.handle().plugin(
                    tauri_plugin_global_shortcut::Builder::new()
                        .with_handler(move |app, shortcut, event| {
                            // Fire on PRESS only. The handler is called for both
                            // press and release, so without this guard one tap
                            // runs the toggle twice — show, then immediately
                            // hide — and the hotkey would look broken while
                            // working perfectly.
                            if shortcut == &hotkey && event.state() == ShortcutState::Pressed {
                                summon_or_dismiss(app);
                            }
                        })
                        .build(),
                )?;

                // A global hotkey is a claim on a key combination for the whole
                // machine, and the OS grants it to whoever asked first. If
                // something else already holds Ctrl+Alt+O this fails, and a
                // silent failure would leave a key that simply does nothing —
                // indistinguishable, from the operator's side, from a bug in
                // this file. So say it, and keep running: a shell that refuses
                // to start because of a convenience key is worse than one
                // without the key.
                match app.global_shortcut().register(hotkey) {
                    Ok(()) => println!("[orion] global hotkey registered: {HOTKEY_HUMAN}"),
                    Err(e) => eprintln!(
                        "[orion] could NOT register {HOTKEY_HUMAN} ({e}). \
                         Another application already holds that combination. \
                         Orion is running and the tray still works — pick a \
                         different combination in src/main.rs to get the hotkey back."
                    ),
                }
            }

            Ok(())
        })
        // ---- condition 6 --------------------------------------------------
        // The X hides. It does not quit. Closing a window is the operator
        // putting him out of sight, which is not the same act as ending the
        // session — and conflating the two is what made SLEEP dishonest.
        // Quitting is deliberate and lives in one place: the tray menu.
        .on_window_event(|window, event| {
            if let WindowEvent::CloseRequested { api, .. } = event {
                api.prevent_close();
                let _ = window.hide();
            }
        })
        .run(tauri::generate_context!())
        .expect("Orion's shell failed to start");
}
