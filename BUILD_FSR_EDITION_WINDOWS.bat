@echo off
setlocal EnableExtensions
cd /d "%~dp0"

set "LOG=%~dp0build_fsr_edition.log"
set "OUTPUT=%~dp0build\release\x64\Binaries"

echo Dolphin FSR Edition - Windows x64 build > "%LOG%"
echo Repository: %CD%>> "%LOG%"
echo.>> "%LOG%"

where git >nul 2>nul
if errorlevel 1 (
  echo ERROR: Git for Windows was not found in PATH.
  echo ERROR: Git for Windows was not found in PATH.>> "%LOG%"
  pause
  exit /b 1
)

where cmake >nul 2>nul
if errorlevel 1 (
  echo ERROR: CMake was not found in PATH.
  echo ERROR: CMake was not found in PATH.>> "%LOG%"
  pause
  exit /b 1
)

echo [1/3] Initializing submodules...
git submodule update --init --recursive >> "%LOG%" 2>&1
if errorlevel 1 (
  echo ERROR: Submodule initialization failed. See build_fsr_edition.log
  pause
  exit /b 1
)

where cl >nul 2>nul
if errorlevel 1 (
  echo ERROR: MSVC compiler was not found in PATH.
  echo Open the x64 Native Tools Command Prompt for Visual Studio, then run this file again.
  echo ERROR: MSVC compiler was not found in PATH.>> "%LOG%"
  pause
  exit /b 1
)

echo [2/3] Configuring and building with Dolphin's Ninja x64 Release preset...
echo Requires MSVC C++ build tools, Windows SDK, CMake and Ninja.
cmake --workflow --preset ninja-release-x64 >> "%LOG%" 2>&1
if errorlevel 1 (
  echo BUILD FAILED. See build_fsr_edition.log for details.
  pause
  exit /b 1
)

echo [3/3] Checking executable...
if not exist "%OUTPUT%\Dolphin.exe" (
  echo Build command completed, but Dolphin.exe was not found at:
  echo %OUTPUT%
  echo Check build_fsr_edition.log and the generated build directory.
  pause
  exit /b 2
)

echo.
echo BUILD COMPLETED.
echo Executable: %OUTPUT%\Dolphin.exe
echo Log: %LOG%
explorer "%OUTPUT%"
pause
