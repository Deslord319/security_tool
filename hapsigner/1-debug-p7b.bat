java -jar hap-sign-tool.jar sign-profile -mode "localSign" -keyAlias "OpenHarmony Application Profile Debug" -keyPwd "123456" -inFile "UnsgnedDebugProfileTemplate.json" -outFile "ohos_provision_debug.p7b" -keystoreFile "OpenHarmony.p12" -keystorePwd "123456" -signAlg "SHA256withECDSA" -profileCertFile "OpenHarmonyProfileDebug.pem"

pause