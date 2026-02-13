@echo off
set PATH=D:\develop\DevEco Studio\jbr\bin;%PATH%
cd /d D:\project\ai\security_tool
node "D:\develop\DevEco Studio\tools\hvigor\bin\hvigorw.js" assembleHap --mode module -p product=default -p module=entry@default
echo Build completed with exit code %ERRORLEVEL%
pause
