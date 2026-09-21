// ============================================================
//  Orion — native shell, milestone 1: a window of his own.
//
//  Deliberately almost empty. The six conditions for "native stands" are:
//    1. opens from a taskbar icon, no browser          <- this milestone
//    2. tray icon reading READY, click to show/hide
//    3. a global hotkey summons him
//    4. the API key encrypted at rest, unlocked by the phrase
//    5. Moon Core works exactly as it does today        <- this milestone
//    6. closing the window does not kill him; the tray quits him
//
//  Each one lands on its own and is verifiable on its own. Building them
//  all at once would mean debugging four unfamiliar things through one
//  symptom, which is how a new toolchain gets blamed for a typo.
// ============================================================

// Release builds get no console window behind the app. Debug builds keep
// it on purpose — it is where panics and webview errors show up.
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

fn main() {
    tauri::Builder::default()
        .run(tauri::generate_context!())
        .expect("Orion's shell failed to start");
}
