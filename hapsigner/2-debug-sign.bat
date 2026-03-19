@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "LATEST_UNSIGNED=%SCRIPT_DIR%..\entry\build\default\outputs\default\entry-default-unsigned.hap"
set "LOCAL_UNSIGNED=%SCRIPT_DIR%entry-default-unsigned.hap"
set "JAVA_EXE=C:\Program Files\Huawei\DevEco Studio\jbr\bin\java.exe"

if not exist "%LATEST_UNSIGNED%" (
  echo Latest unsigned hap not found: %LATEST_UNSIGNED%
  exit /b 1
)

copy /Y "%LATEST_UNSIGNED%" "%LOCAL_UNSIGNED%" >nul
if errorlevel 1 (
  echo Failed to copy latest unsigned hap into hapsigner workspace.
  exit /b 1
)

if not exist "%JAVA_EXE%" (
  echo Java runtime not found: %JAVA_EXE%
  exit /b 1
)

"%JAVA_EXE%" -jar hap-sign-tool.jar sign-app -keyAlias "openharmony application release" -signAlg "SHA256withECDSA" -mode "localSign" -appCertFile "OpenHarmonyApplication.pem" -profileFile "ohos_provision_debug.p7b" -inFile "entry-default-unsigned.hap" -keystoreFile "OpenHarmony.p12" -outFile "signApp.hap" -keyPwd "123456" -keystorePwd "123456"
pause
