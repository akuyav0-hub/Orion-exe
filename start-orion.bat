@echo off
REM ============================================================
REM  start-orion.bat - run Orion locally.
REM
REM  Two bodies, one client. Both modes run the SAME
REM  current\index.html - the native shell references that folder
REM  rather than copying it, so there is no "native version" of
REM  Orion that can drift from the web one.
REM
REM     start-orion              NATIVE  - his own window, no browser
REM     start-orion web          BROWSER - localhost:8000, old behaviour
REM     start-orion web 8081     BROWSER on another port
REM
REM  WHY NATIVE GOES THROUGH cargo AND NOT A BUILT .exe.
REM  Tauri embeds the frontend into the binary at COMPILE time, so
REM  a previously-built orion.exe carries a snapshot of index.html
REM  from whenever it was built. Launching that directly would be
REM  fast and would quietly serve an old Orion - the same class of
REM  mistake as a stale service-worker cache, which this project
REM  has already been bitten by. Going through cargo means what
REM  runs is always what is on disk now. It relinks in seconds
REM  once the first build is done.
REM
REM  WHY THE BROWSER MODE STAYS.
REM  It is not a leftover. localhost is a secure context and is the
REM  only way to exercise the service worker, the PWA install path
REM  and Pet Mode at a narrow width. The native window cannot test
REM  any of those.
REM ============================================================

setlocal

set "ROOT=%~dp0"
set "MODE=%~1"

if /I "%MODE%"=="web"     goto :web
if /I "%MODE%"=="browser" goto :web
goto :native


REM ============================================================
REM  NATIVE
REM ============================================================
:native
set "TAURI=%ROOT%desktop\src-tauri"

if not exist "%TAURI%\tauri.conf.json" (
  echo.
  echo [ERROR] No native shell at "%TAURI%".
  echo         Expected desktop\src-tauri\tauri.conf.json.
  echo         Run "start-orion web" for the browser build instead.
  echo.
  pause
  exit /b 1
)
if not exist "%ROOT%current\index.html" (
  echo.
  echo [ERROR] No build at "%ROOT%current\index.html" - nothing to run.
  echo.
  pause
  exit /b 1
)

where cargo >nul 2>&1
if errorlevel 1 (
  echo.
  echo [ERROR] cargo is not on PATH, so the native shell cannot build.
  echo         If Rust was just installed, open a NEW terminal - rustup
  echo         edits PATH and this window still has the old one.
  echo.
  pause
  exit /b 2
)

echo.
echo === Orion - native ===
echo   Shell   : %TAURI%
echo   Client  : %ROOT%current\index.html
echo.
echo   Build about to run:
findstr /C:"<title>" "%ROOT%current\index.html"
echo.
echo   First run after a Rust change takes a minute. Close the window
echo   or press Ctrl+C here to stop him.
echo.

pushd "%TAURI%"
cargo tauri dev
set "RC=%ERRORLEVEL%"
popd

if not "%RC%"=="0" (
  echo.
  echo [EXIT %RC%] The shell stopped with an error. If it mentions
  echo             "tauri" not being a cargo command, the CLI is missing:
  echo                 cargo install tauri-cli --version "^^2" --locked
  echo.
  pause
)
exit /b %RC%


REM ============================================================
REM  BROWSER  - the original behaviour, unchanged
REM ============================================================
:web
set "SERVE=%ROOT%current"
set "PORT=%~2"
if "%PORT%"=="" set "PORT=8000"

if not exist "%SERVE%\index.html" (
  echo.
  echo [ERROR] No build at "%SERVE%\index.html" - nothing to serve.
  echo.
  pause
  exit /b 1
)

REM ----- find python; the py launcher is the most reliable on Windows -----
set "PY="
where py >nul 2>&1 && set "PY=py -3"
if not defined PY ( where python >nul 2>&1 && set "PY=python" )
if not defined PY ( where python3 >nul 2>&1 && set "PY=python3" )

if not defined PY (
  echo.
  echo [ERROR] No Python on PATH, so the local server cannot start.
  echo Install Python, or serve the current\ folder by any other means.
  echo.
  pause
  exit /b 2
)

echo.
echo === Orion - browser ===
echo   Serving : %SERVE%
echo   Address : http://localhost:%PORT%/index.html
echo.
echo   Build now being served:
findstr /C:"<title>" "%SERVE%\index.html"
echo.
echo   Desktop layout is anything wider than 820px. Narrow the window
echo   under that to get Pet Mode. Close the server window to stop.
echo.

REM ----- server in its own window, then the browser once it is actually up -----
start "Orion local server" /min /d "%SERVE%" cmd /c %PY% -m http.server %PORT%
timeout /t 2 /nobreak >nul
start "" "http://localhost:%PORT%/index.html"

endlocal
