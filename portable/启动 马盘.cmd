@echo off
rem U-Hermes MaPan launcher. Keep this file ASCII-only:
rem cmd.exe parses .bat with the OEM code page, non-ASCII here breaks commands.
setlocal
cd /d "%~dp0app"

set "NODE_EXE=%~dp0runtime\node-win-x64\node.exe"
if not exist "%NODE_EXE%" (
  echo [U-Hermes] Node runtime not found: %NODE_EXE%
  echo [U-Hermes] The USB package looks incomplete. Re-copy the whole U-Hermes folder.
  pause
  exit /b 1
)

"%NODE_EXE%" launch.cjs
set "RC=%ERRORLEVEL%"

if not "%RC%"=="0" (
  echo.
  echo [U-Hermes] Launcher exited with code %RC%.
  pause
)
endlocal
