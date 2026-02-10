java -jar hap-sign-tool.jar sign-app -keyAlias "openharmony application release" -signAlg "SHA256withECDSA" -mode "localSign" -appCertFile "OpenHarmonyApplication.pem" -profileFile "ohos_provision_debug.p7b" -inFile "entry-default-unsigned.hap" -keystoreFile "OpenHarmony.p12" -outFile "signApp.hap" -keyPwd "123456" -keystorePwd "123456"
pause
