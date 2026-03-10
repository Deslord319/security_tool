@echo off
setlocal
set "JAVA_HOME=D:\develop\DevEco Studio\jbr"
set "PATH=%JAVA_HOME%\bin;D:\develop\DevEco Studio\tools\hvigor\bin;%PATH%"
set "PROJECT_DIR=D:\project\ai\security_tool"
set "SRC_HAP=entry\build\default\outputs\default\entry-default-unsigned.hap"
set "DST_HAP=hapsigner\entry-default-unsigned.hap"

cd /d "%PROJECT_DIR%"

echo [1/2] Building unsigned HAP...
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
