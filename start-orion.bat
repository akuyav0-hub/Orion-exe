@echo off
REM ============================================================
REM  start-orion.bat - run the CURRENT build locally.
REM
REM  Serves current\ over http://localhost rather than opening the
REM  file directly, because localhost is a SECURE CONTEXT and
REM  file:// is not. Service worker registration and the PWA
REM  install path both refuse to run from file://, so opening the
REM  html straight off disk would be testing a different app than
REM  the one that actually ships.
REM
REM  Opens index.html and never a version-named file. The previous
REM  version of this script pointed at orion_phase3_4.html, which
REM  stopped existing when the build was renamed to index.html,
REM  and sat broken from then on. index.html is always the live
REM  build, so this cannot rot the same way again.
REM
REM  Usage:
REM     start-orion              serves on port 8000
REM     start-orion 8081         serves on another port
REM ============================================================

setlocal

set "ROOT=%~dp0"
set "SERVE=%ROOT%current"
set "PORT=%~1"
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
echo === Orion - local ===
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
