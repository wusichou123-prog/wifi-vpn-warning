// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:flutter/material.dart' show Color, Size;
import 'package:tray_manager/legacy.dart';
import 'package:window_manager/window_manager.dart';

import 'monitor_controller.dart';

class DesktopIntegration with WindowListener, TrayListener {
  DesktopIntegration(this.controller);

  final MonitorController controller;
  bool _initialized = false;

  Future<void> initialize() async {
    if (!Platform.isWindows) return;
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      size: Size(1120, 760),
      minimumSize: Size(860, 620),
      center: true,
      title: '网络 VPN 警告',
      backgroundColor: Color(0xFFF5F7FA),
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
    await trayManager.setIcon(
      'windows/runner/resources/app_icon.ico',
      iconSize: 18,
    );
    await trayManager.setToolTip('网络 VPN 警告');
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'show', label: '显示主窗口'),
          MenuItem.separator(),
          MenuItem(key: 'exit', label: '退出'),
        ],
      ),
    );
    trayManager.addListener(this);
    windowManager.addListener(this);
    await windowManager.setPreventClose(true);
    _initialized = true;
  }

  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  void onWindowClose() {
    if (controller.config.backgroundMonitoring) {
      windowManager.hide();
    } else {
      _exit();
    }
  }

  @override
  void onTrayIconMouseDown() => _showWindow();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        _showWindow();
      case 'exit':
        _exit();
    }
  }

  Future<void> _exit() async {
    if (_initialized) {
      trayManager.removeListener(this);
      windowManager.removeListener(this);
      await trayManager.destroy();
    }
    await windowManager.destroy();
  }
}
