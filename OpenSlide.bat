@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Open Slide + Codex Launcher

rem ==========================================
rem Open Slide + Codex Windows Launcher
rem First run: Install
rem Next runs: Start
rem No administrator / No auto startup
rem ==========================================

rem ===== Configuration =====

set "BASE=%LOCALAPPDATA%\OpenSlide"
set "NODEDIR=%BASE%\nodejs"
set "NPMGLOBAL=%BASE%\npm-global"
set "NPMCACHE=%BASE%\npm-cache"

set "PROJECT_PARENT=%USERPROFILE%\Documents"
set "PROJECT_NAME=OpenSlideProjects"
set "PROJECT=%PROJECT_PARENT%\%PROJECT_NAME%"

set "TEMPDIR=%TEMP%\OpenSlideInstall"

set "NODE_VERSION=v24.22.2"
set "NODEZIP=node-%NODE_VERSION%-win-x64.zip"
set "NODEURL=https://nodejs.org/dist/%NODE_VERSION%"

set "NODE=%NODEDIR%\node.exe"
set "NPM=%NODEDIR%\npm.cmd"
set "NPX=%NODEDIR%\npx.cmd"
set "CODEX=%NPMGLOBAL%\codex.cmd"

set "PORT=5173"

echo.
echo ==============================================
echo          Open Slide + Codex Launcher
echo ==============================================
echo.

rem ==========================================
rem STEP 0 - Check requirements
rem ==========================================

for %%T in (curl.exe tar.exe certutil.exe robocopy.exe) do (
    where %%T >nul 2>&1
    if errorlevel 1 (
        echo [ERROR] Missing Windows tool: %%T
        goto :fail
    )
)

for %%D in (
    "%BASE%"
    "%NODEDIR%"
    "%NPMGLOBAL%"
    "%NPMCACHE%"
    "%TEMPDIR%"
) do (
    if not exist "%%~D" mkdir "%%~D"
)

rem ==========================================
rem STEP 1 - Node.js
rem ==========================================

echo [1/4] Checking Node.js...

if exist "%NODE%" if exist "%NPM%" (
    "%NODE%" --version >nul 2>&1
    if not errorlevel 1 goto :node_ready
)

echo Installing Node.js %NODE_VERSION%...

set "ZIPFILE=%TEMPDIR%\%NODEZIP%"
set "SHAFILE=%TEMPDIR%\SHASUMS256.txt"
set "HASHOUT=%TEMPDIR%\hash.txt"
set "STAGE=%TEMPDIR%\node-stage"

rem Download official SHA256
echo Downloading official checksums...

curl.exe -fLsS --retry 2 ^
 "%NODEURL%/SHASUMS256.txt" ^
 -o "!SHAFILE!"

if errorlevel 1 (
    echo [ERROR] Cannot download SHA256 file.
    goto :fail
)

rem Get expected hash
set "EXPECTED="

for /f "usebackq tokens=1,2" %%A in ("!SHAFILE!") do (
    if /I "%%B"=="%NODEZIP%" (
        set "EXPECTED=%%A"
    )
)

if not defined EXPECTED (
    echo [ERROR] SHA256 entry not found.
    goto :fail
)

rem Download Node.js ZIP
echo Downloading %NODEZIP%...

curl.exe -fLsS --retry 2 ^
 "%NODEURL%/%NODEZIP%" ^
 -o "!ZIPFILE!"

if errorlevel 1 (
    echo [ERROR] Node.js download failed.
    goto :fail
)

rem Verify checksum
echo Verifying SHA256...

certutil.exe -hashfile "!ZIPFILE!" SHA256 > "!HASHOUT!"

if errorlevel 1 (
    echo [ERROR] SHA256 calculation failed.
    goto :fail
)

set "ACTUAL="

for /f "usebackq skip=1 delims=" %%H in ("!HASHOUT!") do (
    if not defined ACTUAL set "ACTUAL=%%H"
)

set "ACTUAL=!ACTUAL: =!"

if /I not "!ACTUAL!"=="!EXPECTED!" (
    echo.
    echo Expected: !EXPECTED!
    echo Actual:   !ACTUAL!
    echo.
    echo [ERROR] SHA256 verification failed.
    goto :fail
)

echo [OK] SHA256 verified.

rem Extract to staging directory
if exist "!STAGE!" rmdir /s /q "!STAGE!"
mkdir "!STAGE!"

echo Extracting Node.js...

tar.exe -xf "!ZIPFILE!" -C "!STAGE!"

if errorlevel 1 (
    echo [ERROR] Extraction failed.
    goto :fail
)

set "SOURCE=!STAGE!\node-%NODE_VERSION%-win-x64"

if not exist "!SOURCE!\node.exe" (
    echo [ERROR] node.exe missing from ZIP.
    goto :fail
)

if not exist "!SOURCE!\npm.cmd" (
    echo [ERROR] npm.cmd missing from ZIP.
    goto :fail
)

rem Copy files
robocopy "!SOURCE!" "%NODEDIR%" /E /NFL /NDL /NJH /NJS >nul

if !ERRORLEVEL! GEQ 8 (
    echo [ERROR] Node.js copy failed.
    goto :fail
)

if not exist "%NODE%" goto :fail
if not exist "%NPM%" goto :fail

rmdir /s /q "!STAGE!"

echo [OK] Node.js installed.

:node_ready

rem ==========================================
rem Configure current process environment
rem ==========================================

set "PATH=%NODEDIR%;%NPMGLOBAL%;%PATH%"
set "npm_config_prefix=%NPMGLOBAL%"
set "npm_config_cache=%NPMCACHE%"

echo.
echo Node.js version:
"%NODE%" --version
if errorlevel 1 goto :fail

echo npm version:
call "%NPM%" --version
if errorlevel 1 goto :fail

rem ==========================================
rem STEP 2 - Open Slide
rem ==========================================

echo.
echo [2/4] Checking Open Slide...

if exist "%PROJECT%\package.json" (
    echo [OK] Existing project detected.
    goto :project_ready
)

echo Installing Open Slide...

rem Ensure Documents directory exists
if not exist "%PROJECT_PARENT%" (
    mkdir "%PROJECT_PARENT%"
)

rem Do not overwrite non-empty folders
if exist "%PROJECT%" (
    dir /b /a "%PROJECT%" 2>nul | findstr . >nul
    if not errorlevel 1 (
        echo [ERROR] Project directory is not empty.
        echo %PROJECT%
        echo Inspect the directory before retrying.
        goto :fail
    )
)

rem Enter parent directory before init
pushd "%PROJECT_PARENT%"
if errorlevel 1 (
    echo [ERROR] Cannot access Documents folder.
    goto :fail
)

echo Initializing %PROJECT_NAME%...

rem Use a simple directory name
call "%NPX%" --yes @open-slide/cli init ^
 "%PROJECT_NAME%" --use-npm --no-git

set "INIT_RESULT=!ERRORLEVEL!"

popd

if not "!INIT_RESULT!"=="0" (
    echo [ERROR] Open Slide initialization failed.
    goto :fail
)

:project_ready

rem Verify expected project
if not exist "%PROJECT%\package.json" (
    echo [ERROR] package.json not found.
    echo Expected: %PROJECT%
    goto :fail
)

if not exist "%PROJECT%\open-slide.config.ts" (
    echo [ERROR] Invalid Open Slide workspace.
    goto :fail
)

rem Enter project directory safely
pushd "%PROJECT%"
if errorlevel 1 (
    echo [ERROR] Cannot enter project directory.
    goto :fail
)

echo Current project: !CD!

rem Repair dependencies if missing
if not exist "node_modules\.bin\open-slide.cmd" (
    echo Installing Open Slide dependencies...

    call "%NPM%" install

    if errorlevel 1 (
        popd
        echo [ERROR] npm install failed.
        goto :fail
    )
)

if not exist "node_modules\.bin\open-slide.cmd" (
    popd
    echo [ERROR] Open Slide executable missing.
    goto :fail
)

popd

echo [OK] Open Slide ready.

rem ==========================================
rem STEP 3 - Codex CLI
rem ==========================================

echo.
echo [3/4] Checking Codex CLI...

if exist "%CODEX%" (
    call "%CODEX%" --version >nul 2>&1
    if not errorlevel 1 goto :codex_ready
)

echo Installing Codex CLI...

call "%NPM%" install -g @openai/codex@latest --include=optional

if errorlevel 1 (
    echo [ERROR] Codex CLI installation failed.
    goto :fail
)

if not exist "%CODEX%" (
    echo [ERROR] Codex executable not found.
    goto :fail
)

:codex_ready

echo Codex CLI version:
call "%CODEX%" --version

if errorlevel 1 (
    echo [ERROR] Codex CLI cannot execute.
    goto :fail
)

rem ==========================================
rem STEP 4 - Codex Authentication
rem ==========================================

echo.
echo [4/4] Checking Codex authentication...

call "%CODEX%" login status

if errorlevel 1 (
    echo.
    echo [WARNING] Codex login not detected.
    echo.
    echo Login command:
    echo "%CODEX%" login
    echo.
    echo You may continue using Open Slide.
    echo.
)

rem ==========================================
rem Check port availability
rem ==========================================

echo.
echo Checking port %PORT%...

netstat -ano -p TCP | findstr /C:":%PORT% " | findstr /C:"LISTENING" >nul

if not errorlevel 1 (
    echo [WARNING] Port %PORT% is already in use.
    echo Check whether Open Slide is already running.
    echo http://127.0.0.1:%PORT%
    goto :end
)

rem ==========================================
rem Start Open Slide
rem ==========================================

echo.
echo ==============================================
echo              Open Slide Ready
echo ==============================================
echo.
echo URL: http://127.0.0.1:%PORT%
echo Project: %PROJECT%
echo.
echo Press Ctrl+C to stop.
echo ==============================================
echo.

pushd "%PROJECT%"
if errorlevel 1 goto :fail

rem Start browser and local development server
call "%NPM%" run dev -- --host 127.0.0.1 --port %PORT% --open

set "RUN_RESULT=!ERRORLEVEL!"

popd

if not "!RUN_RESULT!"=="0" (
    echo [ERROR] Open Slide startup failed.
    goto :fail
)

goto :end

rem ==========================================
rem Error handler
rem ==========================================

:fail
echo.
echo ==============================================
echo [ERROR] Installation or startup failed.
echo ==============================================
echo.
pause
exit /b 1

:end
echo.
echo Open Slide stopped.
pause
endlocal
