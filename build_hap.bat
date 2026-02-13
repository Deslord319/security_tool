@echo off
set JAVA_HOME=D:\develop\DevEco Studio\jbr
set PATH=%JAVA_HOME%\bin;%PATH%
cd /d D:\project\ai\security_tool
hvigorw assembleHap --mode module -p product=default -p module=entry@default
