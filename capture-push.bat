@echo off
REM ============================================================
REM Orion capture-push.bat
REM
REM Pushes both repositories (project + OCS) to their remotes
REM at a session boundary. Single commit message applies to both.
REM
REM Discipline: this is consciously run, not scheduled. The act
REM of running it is what ratifies "this session is closed."
REM
REM Sub-principle (v0.6e, Session 8):
REM   "Every capture ends with a push to remote."
REM ============================================================

setlocal enabledelayedexpansion

REM ----- Color setup (best effort; works in modern PowerShell/Windows Terminal) -----
set ESC=
set RESET=[0m
set GOLD=[33m
set CYAN=[36m
set RED=[31m
set DIM=[2m

REM ----- Paths -----
set PROJECT_DIR=C:\Users\haro4\Projects\Orion
set OCS_DIR=C:\Users\haro4\Projects\Orion\orion-continuity

REM ============================================================
REM Phase 0 — sanity checks
REM ============================================================
echo.
echo %CYAN%==========================================%RESET%
echo %CYAN% Orion capture-push%RESET%
echo %CYAN% Session-boundary push to both remotes%RESET%
echo %CYAN%==========================================%RESET%
echo.

if not exist "%PROJECT_DIR%\.git" (
  echo %RED%[ERROR]%RESET% Project repo missing: %PROJECT_DIR%\.git not found
  echo Cannot continue. Run from a correctly-set-up project root.
  echo.
  pause
  exit /b 1
)

if not exist "%OCS_DIR%\.git" (
  echo %RED%[ERROR]%RESET% OCS repo missing: %OCS_DIR%\.git not found
  echo Cannot continue. OCS must be a git repo with a remote.
  echo.
  pause
  exit /b 1
)

REM ============================================================
REM Phase 1 — show status of both repos
REM ============================================================
echo %GOLD%[Project repo]%RESET% %PROJECT_DIR%
cd /d "%PROJECT_DIR%"
git status --short
set PROJECT_CHANGES=0
for /f %%i in ('git status --porcelain ^| find /c /v ""') do set PROJECT_CHANGES=%%i
echo %DIM%   %PROJECT_CHANGES% change(s) staged or unstaged%RESET%
echo.

echo %GOLD%[OCS repo]%RESET% %OCS_DIR%
cd /d "%OCS_DIR%"
git status --short
set OCS_CHANGES=0
for /f %%i in ('git status --porcelain ^| find /c /v ""') do set OCS_CHANGES=%%i
echo %DIM%   %OCS_CHANGES% change(s) staged or unstaged%RESET%
echo.

REM ----- If nothing changed anywhere, bail early -----
if "%PROJECT_CHANGES%"=="0" if "%OCS_CHANGES%"=="0" (
  echo %DIM%Nothing to commit in either repo. Both remotes are already current.%RESET%
  echo.
  pause
  exit /b 0
)

REM ============================================================
REM Phase 2 — paranoid pre-commit check on project repo
REM Catch any case where .gitignore failed and secrets might
REM be about to be staged.
REM ============================================================
cd /d "%PROJECT_DIR%"
git status --porcelain | findstr /i /c:"api and recovery keys" /c:".env" /c:".dev.vars" /c:"recovery" > nul
if not errorlevel 1 (
  echo.
  echo %RED%==========================================%RESET%
  echo %RED% SAFETY HALT%RESET%
  echo %RED%==========================================%RESET%
  echo %RED%Possible secret-bearing file in project staging area.%RESET%
  echo Review the status output above. Verify .gitignore is correct.
  echo Aborting without committing.
  echo.
  pause
  exit /b 2
)

REM ============================================================
REM Phase 3 — prompt for commit message
REM ============================================================
echo.
echo %CYAN%Commit message (single line, applies to both repos):%RESET%
echo %DIM%Examples: "Session 8 close: Phase 6 OCS export shipped"%RESET%
echo %DIM%          "Mid-session checkpoint: Dawn voice tests A and B"%RESET%
echo.
set /p COMMIT_MSG="Message: "

if "%COMMIT_MSG%"=="" (
  echo.
  echo %RED%[ERROR]%RESET% Empty commit message. Aborting.
  echo.
  pause
  exit /b 3
)

REM ============================================================
REM Phase 4 — commit + push each repo
REM Project repo first, then OCS. Order matters slightly: code
REM is what runs the canon; if both must land, code lands first.
REM ============================================================

echo.
echo %CYAN%-- Pushing project repo --%RESET%
cd /d "%PROJECT_DIR%"

if not "%PROJECT_CHANGES%"=="0" (
  git add .
  if errorlevel 1 (
    echo %RED%[ERROR]%RESET% git add failed in project repo
    pause
    exit /b 4
  )
  git commit -m "%COMMIT_MSG%"
  if errorlevel 1 (
    echo %RED%[ERROR]%RESET% git commit failed in project repo
    pause
    exit /b 5
  )
  git push
  if errorlevel 1 (
    echo %RED%[ERROR]%RESET% git push failed in project repo
    echo Possible causes: auth expired, network down, remote rejected.
    pause
    exit /b 6
  )
  echo %GOLD%[OK]%RESET% Project repo pushed.
) else (
  echo %DIM%   No changes to commit.%RESET%
)

echo.
echo %CYAN%-- Pushing OCS repo --%RESET%
cd /d "%OCS_DIR%"

if not "%OCS_CHANGES%"=="0" (
  git add .
  if errorlevel 1 (
    echo %RED%[ERROR]%RESET% git add failed in OCS repo
    pause
    exit /b 7
  )
  git commit -m "%COMMIT_MSG%"
  if errorlevel 1 (
    echo %RED%[ERROR]%RESET% git commit failed in OCS repo
    pause
    exit /b 8
  )
  git push
  if errorlevel 1 (
    echo %RED%[ERROR]%RESET% git push failed in OCS repo
    pause
    exit /b 9
  )
  echo %GOLD%[OK]%RESET% OCS repo pushed.
) else (
  echo %DIM%   No changes to commit.%RESET%
)

REM ============================================================
REM Phase 5 — confirm and exit
REM ============================================================
echo.
echo %CYAN%==========================================%RESET%
echo %GOLD% Capture-push complete.%RESET%
echo %CYAN%==========================================%RESET%
echo.
echo Commit message: "%COMMIT_MSG%"
echo.

REM ----- Show the most recent commit on each remote -----
echo %DIM%Latest on project remote:%RESET%
cd /d "%PROJECT_DIR%"
git log origin/main --oneline -1 2>nul
echo.
echo %DIM%Latest on OCS remote:%RESET%
cd /d "%OCS_DIR%"
git log origin/main --oneline -1 2>nul
echo.

pause
exit /b 0
