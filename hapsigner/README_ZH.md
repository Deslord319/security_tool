签名二进制hap-sign-tool.jar预编译工具说明
====================================================

1. 本地配置Gradle环境，要求Gradle7.1以上，查看版本命令如下：

```
gradle -v
```

2. 构建指导
------------------

```
# 获取代码
git clone https://gitee.com/openharmony/developtools_hapsigner.git

# 进入路径developtools_hapsigner/hapsigntool
cd developtools_hapsigner/hapsigntool

# 编译签名工具
gradle build 或者 gradle jar

# 编译后二进制文件位置: ./hap_sign_tool/build/libs/hap-sign-tool.jar
```