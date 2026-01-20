@echo off
setlocal enabledelayedexpansion

REM Run Neovim headless tests from the repository root.
REM This script runs the test suite twice: once under CMD and once under PowerShell
REM to ensure compatibility with both shells on Windows. It also runs in the
REM current environment (works on CI or locally).

REM Determine the repository root. This script is expected to live at:
REM   <repo>\test\scripts\run_tests.bat
REM So repository root is two levels up from this script's directory.
set "REPO=%~dp0\..\.."
REM Normalize path (remove trailing backslash if present)
if "%REPO:~-1%"=="\" set "REPO=%REPO:~0,-1%"

echo Repo root: "%REPO%"
pushd "%REPO%" || (
  echo Failed to change directory to repo: "%REPO%"
  exit /b 2
)

REM Ensure nvim is available in PATH
where nvim >nul 2>&1
if errorlevel 1 (
  echo nvim not found in PATH.
  popd
  exit /b 3
)

echo.
echo === CMD: running tests in %REPO% ===
REM Run tests in a single headless Neovim invocation under CMD.
REM We load the test files and call their runners. The exit code will indicate success/failure.
nvim --headless "+luafile test/test_search_venvs.lua" "+lua run_all_tests()" "+luafile test/test_config_options.lua" "+lua run_config_tests()" +q
set "CMD_EXIT=%ERRORLEVEL%"

echo.
echo CMD exit code: %CMD_EXIT%
echo.

echo === PowerShell: running tests in %REPO% ===
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop';" ^
  "Set-Location -LiteralPath '%REPO%';" ^
  "if (-not (Get-Command nvim -ErrorAction SilentlyContinue)) { throw 'nvim not found in PATH' };" ^
  "& nvim --headless '+luafile test/test_search_venvs.lua' '+lua run_all_tests()' '+luafile test/test_config_options.lua' '+lua run_config_tests()' +q;" ^
  "exit $LASTEXITCODE"
set "PS_EXIT=%ERRORLEVEL%"

echo.
echo PowerShell exit code: %PS_EXIT%
echo.

popd

REM Final exit code: fail if either failed
if not "%CMD_EXIT%"=="0" exit /b %CMD_EXIT%
if not "%PS_EXIT%"=="0" exit /b %PS_EXIT%
echo All tests completed successfully under CMD and PowerShell.
exit /b 0