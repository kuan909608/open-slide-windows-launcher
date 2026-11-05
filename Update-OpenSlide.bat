@echo off
setlocal EnableExtensions DisableDelayedExpansion
if not exist "%~dp0OpenSlide.bat" (
    echo [ERROR] Keep this file beside OpenSlide.bat.
    pause
    exit /b 1
)
call "%~dp0OpenSlide.bat" update
set "result=%errorlevel%"
echo.
pause
exit /b %result%
