@echo off
setlocal
set "WEB_DIR=%~dp0build\web"

if not exist "%WEB_DIR%\index.html" (
    echo Space web build was not found at:
    echo %WEB_DIR%
    pause
    exit /b 1
)

start "Space Web Server" /min python "%~dp0tools\serve_web.py" --port 8000 --open

endlocal
