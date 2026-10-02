import 'dart:io';

import 'package:flutter/material.dart';

import '../services/monitor_controller.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.controller});

  final MonitorController controller;

  @override
  Widget build(BuildContext context) {
    final config = controller.config;
    final permission = controller.permissions;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('监控与权限', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.play_circle_outline),
                title: const Text('持续后台监控'),
                subtitle: const Text('Android 前台服务；Windows 关闭窗口后驻留托盘。'),
                value: config.backgroundMonitoring,
                onChanged: (value) => controller.saveConfig(
                  config.copyWith(
                    backgroundMonitoring: value,
                    startAtLogin: value && config.startAtLogin,
                  ),
                ),
              ),
              if (Platform.isWindows)
                SwitchListTile(
                  secondary: const Icon(Icons.login),
                  title: const Text('登录后自动启动'),
                  subtitle: const Text('仅在选择持续后台监控时生效。'),
                  value: config.startAtLogin,
                  onChanged: (value) => controller.saveConfig(
                    config.copyWith(startAtLogin: value),
                  ),
                ),
              if (Platform.isAndroid)
                SwitchListTile(
                  secondary: const Icon(Icons.layers_outlined),
                  title: const Text('悬浮窗覆盖提醒'),
                  subtitle: const Text('需要 Android 悬浮窗权限。'),
                  value: config.overlayEnabled,
                  onChanged: (value) async {
                    await controller.saveConfig(
                      config.copyWith(overlayEnabled: value),
                    );
                    if (value) {
                      await controller.openOverlaySettings();
                    }
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: const Text('Wi-Fi 名称权限'),
                trailing: PermissionBadge(
                  granted: permission?.locationGranted ?? false,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.notifications_outlined),
                title: const Text('通知权限'),
                trailing: PermissionBadge(
                  granted: permission?.notificationGranted ?? true,
                ),
              ),
              if (Platform.isAndroid)
                ListTile(
                  leading: const Icon(Icons.layers_outlined),
                  title: const Text('悬浮窗权限'),
                  trailing: PermissionBadge(
                    granted: permission?.overlayGranted ?? false,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: controller.requestPermissions,
                      icon: const Icon(Icons.verified_user_outlined),
                      label: const Text('检查并申请权限'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Card(
          child: ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('告警判定'),
            subtitle: Text('仅在系统真实 VPN 隧道或明确系统代理处于开启状态，并且 Wi-Fi/时间规则命中时告警。'),
          ),
        ),
        const SizedBox(height: 16),
        const Card(
          child: ListTile(
            leading: Icon(Icons.privacy_tip_outlined),
            title: Text('隐私说明'),
            subtitle: Text('所有检测均在本机完成。程序不会上传 SSID、VPN/代理状态或时间规则。'),
          ),
        ),
      ],
    );
  }
}

class PermissionBadge extends StatelessWidget {
  const PermissionBadge({super.key, required this.granted});

  final bool granted;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(
        granted ? Icons.check_circle : Icons.info_outline,
        size: 18,
        color: granted ? Colors.green : Colors.orange,
      ),
      label: Text(granted ? '已授权' : '未授权'),
    );
  }
}
