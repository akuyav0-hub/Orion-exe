@echo off
REM ============================================================
REM  push-orion.bat - the standard Orion deploy.
REM
REM  Usage:
REM     push-orion                     (prompts for a message)
REM     push-orion v0.6h.4 - device pass III
REM
REM  Runs verify.sh FIRST and refuses to push if it fails.
REM  Finds Git's bash.exe on its own - no PATH setup needed.
REM ============================================================
setlocal EnableDelayedExpansion

set "REPO=C:\Users\haro4\Projects\Orion"
cd /d "%REPO%" || (echo Could not find %REPO% & pause & exit /b 1)

echo.
echo === Orion deploy ===
echo Repo: %REPO%
echo.

REM ---------- find bash.exe ----------
REM Try PATH first, then the usual Git for Windows install locations.
set "BASH="
where bash.exe >nul 2>&1 && set "BASH=bash.exe"

if not defined BASH if exist "%ProgramFiles%\Git\bin\bash.exe" set "BASH=%ProgramFiles%\Git\bin\bash.exe"
if not defined BASH if exist "%ProgramFiles(x86)%\Git\bin\bash.exe" set "BASH=%ProgramFiles(x86)%\Git\bin\bash.exe"
if not defined BASH if exist "%LOCALAPPDATA%\Programs\Git\bin\bash.exe" set "BASH=%LOCALAPPDATA%\Programs\Git\bin\bash.exe"
if not defined BASH if exist "C:\Program Files\Git\bin\bash.exe" set "BASH=C:\Program Files\Git\bin\bash.exe"

REM ---------- 1. pre-deploy integrity gate ----------
if not defined BASH (
  echo [1/4] SKIPPED - could not find bash.exe, so verify did not run.
  echo       Install Git for Windows, or run verify manually in Git Bash.
  echo.
  set /p "GOON=Push anyway without verifying? (y/N): "
  if /I not "!GOON!"=="y" (
    echo Aborted.
    pause
    exit /b 1
  )
) else (
  echo [1/4] Running verify...
  pushd current
  "%BASH%" verify.sh
  set "VERIFY_RC=!ERRORLEVEL!"
  popd

  if not "!VERIFY_RC!"=="0" (
    echo.
    echo *** VERIFY FAILED - nothing pushed. Fix the failures above. ***
    pause
    exit /b 1
  )
)

REM ---------- 2. remind about the service worker cache ----------
echo.
findstr /C:"const CACHE" current\sw.js
echo   ^^ If you changed index.html, this cache name MUST be new,
echo      or returning devices keep serving the old build.
echo.

REM ---------- 3. commit message ----------
set "MSG=%*"
if "%MSG%"=="" set /p "MSG=Commit message: "
if "%MSG%"=="" (
  echo No message given - aborting.
  pause
  exit /b 1
)

REM ---------- 4. commit and push ----------
echo.
echo [2/4] Staging...
git add .

echo [3/4] Committing...
git commit -m "%MSG%"
if errorlevel 1 echo   (nothing new to commit - continuing)

echo [4/4] Syncing and pushing...
git pull origin main --no-edit
if errorlevel 1 (
  echo.
  echo *** PULL FAILED - likely a merge conflict. Resolve it, then push manually. ***
  pause
  exit /b 1
)

git push
if errorlevel 1 (
  echo.
  echo *** PUSH FAILED - see the message above. ***
  pause
  exit /b 1
)

echo.
echo === Pushed. Check Actions for the green check. ===
echo   Then on the phone: delete the home-screen app,
echo   reload in Safari, re-add. Otherwise the old service
echo   worker keeps serving the previous build.
echo.
pause
