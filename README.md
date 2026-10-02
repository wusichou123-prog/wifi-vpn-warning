# 网络 VPN 警告

一个面向 Windows 10/11 和 Android 10+（包含 OriginOS）的本地网络告警程序。当系统 VPN 或明确配置的系统代理开启，并且当前 Wi-Fi 或时间命中用户规则时，程序会弹出强提醒。

## 功能

- 显示当前连接的 Wi-Fi 名称
- 检测 Windows/Android 系统 VPN 状态
- 检测明确配置的系统 HTTP/PAC 代理
- 支持添加多个 Wi-Fi 名称规则
- 支持添加星期、开始时间和结束时间规则
- Windows 托盘运行及可选的登录自启动
- Android 前台服务、通知和可选悬浮窗提醒
- 所有数据均在本机处理，不上传网络状态或个人配置

## 规则

告警条件为：

```text
(VPN 或系统代理已开启) 且 (Wi-Fi 规则命中 或 时间规则命中)
```

Wi-Fi 名称采用不区分大小写的精确匹配。时间使用设备本地时区，开始时刻包含、结束时刻不包含。

## 平台限制

- Android 读取 Wi-Fi 名称需要定位或附近 Wi-Fi 设备权限。
- Android 无 Root 时无法扫描其他应用内部的本地代理进程。
- Android 可检测系统 VPN、系统代理以及通过 Android VPN 服务实现的代理。
- Windows 需要系统真实建立 VPN 隧道，或存在明确配置的系统代理，才会认为 VPN/代理已开启。

## 本地构建

要求 Flutter 3.47 或兼容版本，并完成对应平台工具链配置。

```powershell
flutter pub get
flutter analyze
flutter test
flutter build windows --release
flutter build apk --release
```

构建产物位置：

```text
build/windows/x64/runner/Release/
build/app/outputs/flutter-apk/app-release.apk
```

## 下载安装

Windows 和 Android 安装包通过 GitHub Releases 发布。

- Windows：解压发布包后运行 `wifi_warning.exe`，不要将 EXE 与旁边的 DLL 和 `data` 目录分离。
- Android：将 APK 传到手机并允许安装未知来源应用。

## 隐私

程序不会上传 SSID、VPN/代理状态、时间规则或其他用户数据。Windows 配置保存在 `%APPDATA%\WifiWarning\config.json`，Android 配置保存在应用私有数据目录。

## 免责声明

本程序仅用于个人网络状态提醒，不替代组织安全策略或专业网络安全工具。
