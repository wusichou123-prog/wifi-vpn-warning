import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/app_config.dart';
import '../models/detection_snapshot.dart';
import 'platform_monitor.dart';
import 'rule_engine.dart';

class AlertNotice {
  const AlertNotice({required this.title, required this.message});

  final String title;
  final String message;
}

class MonitorController extends ChangeNotifier {
  MonitorController(this._platform);

  final PlatformMonitor _platform;
  final RuleEngine _engine = const RuleEngine();

  AppConfig _config = const AppConfig();
  DetectionSnapshot? _snapshot;
  AlertNotice? _alert;
  PermissionStatus? _permissions;
  StreamSubscription<DetectionSnapshot>? _snapshotSubscription;
  Timer? _heartbeat;
  bool _initialized = false;
  bool _alertLatched = false;
  String? _error;

  AppConfig get config => _config;
  DetectionSnapshot? get snapshot => _snapshot;
  AlertNotice? get alert => _alert;
  PermissionStatus? get permissions => _permissions;
  bool get initialized => _initialized;
  String? get error => _error;
  bool get isWindows => Platform.isWindows;

  Future<void> initialize() async {
    try {
      _config = AppConfig.decode(await _platform.loadConfig());
      if (Platform.isAndroid) {
        _snapshotSubscription = _platform.snapshots.listen(
          _handleSnapshot,
          onError: (_) {},
        );
      }
      await refresh();
      await _platform.setMonitoringEnabled(_config.backgroundMonitoring);
      await _platform.setStartAtLogin(
        _config.backgroundMonitoring && _config.startAtLogin,
      );
      _startHeartbeat();
    } catch (error) {
      _error = error.toString();
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    final interval = Platform.isWindows
        ? const Duration(seconds: 2)
        : const Duration(seconds: 15);
    _heartbeat = Timer.periodic(interval, (_) => refresh());
  }

  Future<void> refresh() async {
    try {
      final next = await _platform.getSnapshot(_config);
      _handleSnapshot(next);
      _error = null;
    } catch (error) {
      _error = error.toString();
      notifyListeners();
    }
  }

  void _handleSnapshot(DetectionSnapshot next) {
    _snapshot = next;
    if (Platform.isWindows) {
      _evaluateWindowsAlert(next);
    }
    notifyListeners();
  }

  void _evaluateWindowsAlert(DetectionSnapshot current) {
    final result = _engine.evaluate(_config, current);
    if (!result.shouldAlert) {
      _alertLatched = false;
      return;
    }
    if (_alertLatched) {
      return;
    }
    _alertLatched = true;
    final message = [
      if (current.wifiSsid != null) '当前 Wi-Fi：${current.wifiSsid}',
      if (current.vpnActive) '检测到 VPN',
      if (current.proxyActive) '检测到系统代理',
      ...result.reasons,
    ].join('\n');
    _alert = AlertNotice(title: '网络安全警告', message: message);
    _platform.showAlert(title: _alert!.title, message: message);
  }

  Future<void> saveConfig(AppConfig next) async {
    _config = next;
    _alertLatched = false;
    await _platform.saveConfig(next);
    await _platform.setMonitoringEnabled(next.backgroundMonitoring);
    await _platform.setStartAtLogin(
      next.backgroundMonitoring && next.startAtLogin,
    );
    notifyListeners();
    await refresh();
  }

  Future<void> completeOnboarding({
    required bool backgroundMonitoring,
    required bool overlayEnabled,
  }) async {
    _config = _config.copyWith(
      backgroundMonitoring: backgroundMonitoring,
      startAtLogin: backgroundMonitoring,
      overlayEnabled: overlayEnabled,
      firstRunCompleted: true,
    );
    await _platform.saveConfig(_config);
    await _platform.setStartAtLogin(backgroundMonitoring);
    await _platform.setMonitoringEnabled(backgroundMonitoring);
    notifyListeners();
    await refresh();
  }

  Future<void> requestPermissions() async {
    _permissions = await _platform.requestPermissions();
    notifyListeners();
    await refresh();
  }

  Future<void> openOverlaySettings() async {
    await _platform.openOverlaySettings();
    await Future<void>.delayed(const Duration(seconds: 1));
    await requestPermissions();
  }

  void dismissAlert() {
    _alert = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _heartbeat?.cancel();
    _snapshotSubscription?.cancel();
    super.dispose();
  }
}
