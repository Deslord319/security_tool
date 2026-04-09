@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
set "PROJECT_DIR=%SCRIPT_DIR:~0,-1%"
set "SRC_HAP=entry\build\default\outputs\default\entry-default-unsigned.hap"
set "DST_HAP=hapsigner\entry-default-unsigned.hap"
set "HVIGORW_CMD="
set "IDE_HOME="
set "JAVA_BIN_DIR="

if not defined IDE_HOME if defined DEVECOSTUDIO_HOME (
  set "IDE_HOME=%DEVECOSTUDIO_HOME%"
)

if not defined IDE_HOME if exist "C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" (
  set "IDE_HOME=C:\Program Files\Huawei\DevEco Studio"
)

if not defined IDE_HOME if defined JAVA_HOME (
  for %%I in ("%JAVA_HOME%\..") do set "IDE_HOME=%%~fI"
)

if defined IDE_HOME if exist "%IDE_HOME%\jbr\bin\java.exe" (
  set "JAVA_BIN_DIR=%IDE_HOME%\jbr\bin"
) else if defined JAVA_HOME if exist "%JAVA_HOME%\bin\java.exe" (
  set "JAVA_BIN_DIR=%JAVA_HOME%\bin"
)

if not defined HVIGORW_CMD if defined IDE_HOME if exist "%IDE_HOME%\tools\hvigor\bin\hvigorw.bat" (
  set "HVIGORW_CMD=%IDE_HOME%\tools\hvigor\bin\hvigorw.bat"
)

if not defined HVIGORW_CMD if exist "C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" (
  set "HVIGORW_CMD=C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat"
)

if defined JAVA_BIN_DIR (
  set "PATH=%JAVA_BIN_DIR%;C:\Windows\System32;C:\Windows;%PATH%"
)

cd /d "%PROJECT_DIR%"

echo [1/2] Building unsigned HAP...
if not defined HVIGORW_CMD (
  echo hvigorw not found. Please ensure DevEco Studio is installed, for example:
  echo   C:\Program Files\Huawei\DevEco Studio
  echo Or set DEVECOSTUDIO_HOME / JAVA_HOME before running this script.
  endlocal
  exit /b 1
)

call "%HVIGORW_CMD%" --no-daemon assembleHap --mode module -p product=default -p module=entry@default
if errorlevel 1 (
  echo hvigor assembleHap failed with exit code %ERRORLEVEL%.
  echo Official PackageHap did not complete. Stop here to avoid producing an invalid HAP.
  goto :build_fail
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
exit /b 0

:build_fail
echo Build failed.
endlocal
exit /b 1
