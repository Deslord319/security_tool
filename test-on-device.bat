@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

:: ============================================================
:: HarmonyShield 真机测试脚本
:: 功能：构建 → 签名 → 安装 → 激活 → 运行自动化测试
:: ============================================================

echo.
echo ╔══════════════════════════════════════════════════════╗
echo ║     HarmonyShield 真机测试脚本 v1.0                  ║
echo ║     HarmonyOS Enterprise Security Management         ║
echo ╚══════════════════════════════════════════════════════╝
echo.

:: 检查 HDC 是否安装
echo [检查] 检查 HDC 工具...
where hdc >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ 错误：未找到 hdc 工具
    echo.
    echo 请确保已安装 DevEco Studio 并配置环境变量
    echo 或添加 HDC 路径到 PATH:
    echo   C:\Huawei\Sdk\toolchains\hdc.exe
    exit /b 1
)
echo ✅ HDC 工具已找到

:: 检查设备连接
echo.
echo [步骤 1/6] 检查设备连接...
hdc list targets >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ 错误：未检测到设备
    echo.
    echo 请确保：
    echo 1. 设备已通过 USB 连接电脑
    echo 2. 设备已开启 USB 调试模式
    echo 3. 已授权电脑进行调试
    echo.
    echo 使用无线调试连接：
    echo   hdc tconn 192.168.1.100:5555
    exit /b 1
)

echo ✅ 设备已连接
hdc list targets

:: 构建 HAP
echo.
echo [步骤 2/6] 构建 HAP...
if exist "build_hap.bat" (
    call build_hap.bat
    if %errorlevel% neq 0 (
        echo ❌ 构建失败
        exit /b 1
    )
) else if exist "hvigorw.bat" (
    call hvigorw.bat assembleHap --mode module -p product=default -p module=entry
    if %errorlevel% neq 0 (
        echo ❌ 构建失败
        exit /b 1
    )
) else (
    echo ❌ 未找到构建脚本
    exit /b 1
)
echo ✅ 构建完成

:: 检查构建产物
echo.
echo [步骤 3/6] 检查构建产物...
set HAP_FILE=entry\build\default\outputs\default\entry-default-unsigned.hap
if not exist "%HAP_FILE%" (
    echo ❌ 错误：未找到构建产物 %HAP_FILE%
    exit /b 1
)
echo ✅ 构建产物已找到
dir /b "%HAP_FILE%"

:: 签名 HAP
echo.
echo [步骤 4/6] 签名 HAP...
if not exist "hapsigner" (
    echo ❌ 错误：未找到签名目录 hapsigner/
    exit /b 1
)

cd hapsigner
copy ..\%HAP_FILE% entry-default-unsigned.hap >nul

if exist "2-debug-sign.bat" (
    call 2-debug-sign.bat
    if %errorlevel% neq 0 (
        echo ❌ 签名失败
        cd ..
        exit /b 1
    )
) else if exist "hap-sign-tool.jar" (
    java -jar hap-sign-tool.jar sign-app ^
      -keyAlias "openharmony application release" ^
      -signAlg "SHA256withECDSA" ^
      -mode "localSign" ^
      -appCertFile "OpenHarmonyApplication.pem" ^
      -profileFile "ohos_provision_debug.p7b" ^
      -inFile "entry-default-unsigned.hap" ^
      -keystoreFile "OpenHarmony.p12" ^
      -outFile "signApp.hap" ^
      -keyPwd "123456" ^
      -keystorePwd "123456"
    
    if %errorlevel% neq 0 (
        echo ❌ 签名失败
        cd ..
        exit /b 1
    )
) else (
    echo ❌ 错误：未找到签名工具
    cd ..
    exit /b 1
)
cd ..

if exist "hapsigner\signApp.hap" (
    echo ✅ 签名完成
    dir /b "hapsigner\signApp.hap"
) else (
    echo ❌ 错误：签名失败，未找到 signApp.hap
    exit /b 1
)

:: 安装到设备
echo.
echo [步骤 5/6] 安装到设备...
hdc install hapsigner\signApp.hap
if %errorlevel% neq 0 (
    echo ❌ 安装失败
    echo.
    echo 可能原因:
    echo 1. 设备未连接
    echo 2. 签名配置不正确
    echo 3. 设备存储空间不足
    exit /b 1
)
echo ✅ 安装完成

:: 激活企业管理员
echo.
echo [步骤 6/6] 激活企业管理员...
echo 注意：此步骤用于激活 MDM 功能，仅企业版设备支持
echo.
hdc shell edm enable-admin -n com.huawei.securitytool -a EnterpriseAdminAbility -t super
if %errorlevel% neq 0 (
    echo ⚠️  激活失败（可能是正常现象）
    echo.
    echo 可能原因:
    echo 1. 设备不是企业版
    echo 2. 设备未激活 MDM 模式
    echo 3. 普通消费者设备不支持
    echo.
    echo 提示：如果只是测试基本功能，可以跳过此步骤
) else (
    echo ✅ 企业管理员已激活
)

:: 验证安装
echo.
echo ════════════════════════════════════════════════════════
echo 测试准备完成！
echo ════════════════════════════════════════════════════════
echo.
echo 📱 应用信息:
echo   包名：com.huawei.securitytool
echo   版本：v17
echo   路径：hapsigner\signApp.hap
echo.
echo 🎯 下一步操作:
echo   1. 在设备上打开 HarmonyShield 应用
echo   2. 按照测试清单手动测试功能
echo   3. 填写测试报告模板
echo.
echo 📋 测试报告位置:
echo   docs\test-report-DATE.md
echo.
echo 🔧 常用命令:
echo   查看已安装应用:
echo     hdc shell bm list
echo.
echo   启动应用:
echo     hdc shell am start -n com.huawei.securitytool/.EntryAbility
echo.
echo   查看应用日志:
echo     hdc hilog
echo.
echo   卸载应用:
echo     hdc uninstall com.huawei.securitytool
echo.
echo ════════════════════════════════════════════════════════
echo.
pause
