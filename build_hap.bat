@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
set "PROJECT_DIR=%SCRIPT_DIR:~0,-1%"
set "SRC_HAP=entry\build\default\outputs\default\entry-default-unsigned.hap"
set "DST_HAP=hapsigner\entry-default-unsigned.hap"
set "HVIGOR_BIN="
set "IDE_HOME="

if defined JAVA_HOME (
  set "PATH=%JAVA_HOME%\bin;%PATH%"
)

if not defined IDE_HOME if defined DEVECOSTUDIO_HOME (
  set "IDE_HOME=%DEVECOSTUDIO_HOME%"
)

if not defined IDE_HOME if exist "%ProgramFiles%\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" (
  set "IDE_HOME=%ProgramFiles%\Huawei\DevEco Studio"
)

if not defined IDE_HOME if exist "%ProgramFiles(x86)%\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" (
  set "IDE_HOME=%ProgramFiles(x86)%\Huawei\DevEco Studio"
)

if not defined IDE_HOME if defined JAVA_HOME (
  for %%I in ("%JAVA_HOME%\..") do set "IDE_HOME=%%~fI"
)

if defined IDE_HOME if exist "%IDE_HOME%\tools\hvigor\bin\hvigorw.bat" (
  set "HVIGOR_BIN=%IDE_HOME%\tools\hvigor\bin"
  set "PATH=%HVIGOR_BIN%;%PATH%"
)

cd /d "%PROJECT_DIR%"

echo [1/2] Building unsigned HAP...
where hvigorw >nul 2>nul
if errorlevel 1 (
  echo hvigorw not found. Please ensure DevEco Studio is installed, for example:
  echo   C:\Program Files\Huawei\DevEco Studio
  echo Or set DEVECOSTUDIO_HOME / JAVA_HOME before running this script.
  endlocal
  exit /b 1
)

call hvigorw assembleHap --mode module -p product=default -p module=entry@default
if errorlevel 1 (
  echo Build failed with exit code %ERRORLEVEL%.
  endlocal
  exit /b %ERRORLEVEL%
)

if not exist "%SRC_HAP%" (
  echo Build output not found: %SRC_HAP%
  endlocal
  exit /b 1
)

echo [2/2] Syncing unsigned HAP for signer...
copy /Y "%SRC_HAP%" "%DST_HAP%" >nul
if errorlevel 1 (
  echo Failed to copy %SRC_HAP% to %DST_HAP%.
  endlocal
  exit /b %ERRORLEVEL%
)

echo.
echo Build and sync completed.
for %%I in ("%SRC_HAP%") do echo SRC %%~fI ^| size=%%~zI ^| time=%%~tI
for %%I in ("%DST_HAP%") do echo DST %%~fI ^| size=%%~zI ^| time=%%~tI

endlocal
