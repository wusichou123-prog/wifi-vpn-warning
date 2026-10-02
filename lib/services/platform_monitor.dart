import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import '../models/app_config.dart';
import '../models/detection_snapshot.dart';

class PermissionStatus {
  const PermissionStatus({
    required this.locationGranted,
    required this.notificationGranted,
    required this.overlayGranted,
  });

  final bool locationGranted;
  final bool notificationGranted;
  final bool overlayGranted;

  factory PermissionStatus.fromMap(Map<dynamic, dynamic> map) {
    return PermissionStatus(
      locationGranted: map['locationGranted'] as bool? ?? false,
      notificationGranted: map['notificationGranted'] as bool? ?? true,
      overlayGranted: map['overlayGranted'] as bool? ?? false,
    );
  }
}

class PlatformMonitor {
  static const MethodChannel _method = MethodChannel('wifi_warning/monitor');
  static const EventChannel _events = EventChannel(
    'wifi_warning/monitor_events',
  );

  Stream<DetectionSnapshot> get snapshots => _events
      .receiveBroadcastStream()
      .map((event) => DetectionSnapshot.fromMap(event as Map));

  Future<String?> loadConfig() async {
    return _method.invokeMethod<String>('loadConfig');
  }

  Future<void> saveConfig(AppConfig config) async {
    await _method.invokeMethod<void>('saveConfig', <String, Object>{
      'json': config.encode(),
    });
  }

  Future<DetectionSnapshot> getSnapshot(AppConfig config) async {
    try {
      final result = await _method.invokeMethod<Map<dynamic, dynamic>>(
        'getSnapshot',
        <String, Object>{'processPatterns': config.proxyProcessPatterns},
      );
      return DetectionSnapshot.fromMap(result ?? const {});
    } on PlatformException catch (error) {
      return DetectionSnapshot.unavailable(error.message);
    } on MissingPluginException {
      return DetectionSnapshot.unavailable('当前平台不支持系统检测');
    }
  }

  Future<void> setMonitoringEnabled(bool enabled) async {
    await _method.invokeMethod<void>('setMonitoringEnabled', <String, Object>{
      'enabled': enabled,
    });
  }

  Future<void> setStartAtLogin(bool enabled) async {
    if (!Platform.isWindows) {
      return;
    }
    await _method.invokeMethod<void>('setStartAtLogin', <String, Object>{
      'enabled': enabled,
    });
  }

  Future<PermissionStatus> requestPermissions() async {
    final result = await _method.invokeMethod<Map<dynamic, dynamic>>(
      'requestPermissions',
    );
    return PermissionStatus.fromMap(result ?? const {});
  }

  Future<void> openOverlaySettings() async {
    await _method.invokeMethod<void>('openOverlaySettings');
  }

  Future<void> showAlert({
    required String title,
    required String message,
  }) async {
    await _method.invokeMethod<void>('showAlert', <String, Object>{
      'title': title,
      'message': message,
    });
  }
}
