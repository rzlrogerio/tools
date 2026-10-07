@echo off
REM scan_local_image.bat - Windows wrapper for scan_local_image.py
REM Usage: scan_local_image.bat <image_id> [options]

setlocal enabledelayedexpansion
set "SCRIPT_DIR=%~dp0"
set "PYTHON_SCRIPT=%SCRIPT_DIR%scan_local_image.py"

if not exist "%PYTHON_SCRIPT%" (
    echo [ERROR] Python script not found: %PYTHON_SCRIPT%
    exit /b 1
)

REM Execute Python script with all arguments passed through
python "%PYTHON_SCRIPT%" %*
exit /b !ERRORLEVEL!
