# 信用卡档案 Android 测试版

这是一个安卓 WebView 测试壳，内置当前 H5 页面。

## 当前能力

- 打开后直接进入信用卡档案工具
- 不需要联网
- 不请求敏感权限
- 数据保存在手机本机 WebView 的 localStorage
- 可以继续用 H5 的 JSON 导入/导出做备份

## 打包 APK

这台机器当前没有 Android SDK 和 Gradle，所以这里先提供可打开的 Android 项目。

### 方法一：GitHub Actions 云打包

把整个项目上传到 GitHub 仓库后：

1. 打开仓库的 `Actions`
2. 选择 `Build Android APK`
3. 点击 `Run workflow`
4. 等构建完成
5. 在本次构建页面的 `Artifacts` 下载 `credit-card-archive-debug-apk`
6. 解压后得到 `app-debug.apk`
7. 发到安卓手机安装

这个 APK 是 debug 版，适合自己测试安装，不适合上架应用商店。

### 方法二：Android Studio 本地打包

在装有 Android Studio 的电脑上：

1. 打开 `android` 目录
2. 等 Android Studio 同步 Gradle
3. 选择 `Build > Build Bundle(s) / APK(s) > Build APK(s)`
4. 生成 APK 后发到自己的安卓手机
5. 手机上允许“安装未知来源应用”即可安装

## 注意

当前版本不要录入完整卡号、有效期、CVV、安全码、网银密码、短信验证码。
