@echo off
set JAVA_HOME=C:\Program Files\Huawei\DevEco Studio\jbr
set PATH=%JAVA_HOME%\bin;%PATH%
hvigorw.bat assembleHap --mode module -p product=default -p module=entry
