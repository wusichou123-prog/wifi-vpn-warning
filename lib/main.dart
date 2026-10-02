import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'services/desktop_integration.dart';
import 'services/monitor_controller.dart';
import 'services/platform_monitor.dart';
import 'ui/app.dart';

final monitorControllerProvider = Provider<MonitorController>(
  (ref) => throw UnimplementedError(),
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = MonitorController(PlatformMonitor());
  await controller.initialize();
  final desktopIntegration = DesktopIntegration(controller);
  await desktopIntegration.initialize();
  runApp(
    ProviderScope(
      overrides: [monitorControllerProvider.overrideWithValue(controller)],
      child: const WifiWarningApp(),
    ),
  );
}
