import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../main.dart';
import '../services/monitor_controller.dart';
import 'dashboard_page.dart';
import 'network_rules_page.dart';
import 'settings_page.dart';
import 'time_rules_page.dart';
import 'widgets.dart';

class WifiWarningApp extends ConsumerWidget {
  const WifiWarningApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(monitorControllerProvider);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '网络 VPN 警告',
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF165DFF),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: Colors.white,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      home: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          if (!controller.initialized) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (!controller.config.firstRunCompleted) {
            return OnboardingPage(controller: controller);
          }
          return HomeShell(controller: controller);
        },
      ),
    );
  }
}

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.controller});

  final MonitorController controller;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  bool background = false;
  bool overlay = false;
  bool saving = false;

  Future<void> _finish() async {
    setState(() => saving = true);
    await widget.controller.completeOnboarding(
      backgroundMonitoring: background,
      overlayEnabled: overlay,
    );
    if (overlay && Platform.isAndroid) {
      await widget.controller.openOverlaySettings();
    } else {
      await widget.controller.requestPermissions();
    }
    if (mounted) setState(() => saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.shield_outlined, size: 52),
                    const SizedBox(height: 18),
                    Text(
                      '网络 VPN 警告',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '程序只在本地检测 Wi-Fi、VPN、系统代理和规则时间，不会上传任何网络信息。',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),
                    const FeatureLine(
                      icon: Icons.wifi,
                      text: '显示当前实际连接的 Wi-Fi 名称',
                    ),
                    const FeatureLine(
                      icon: Icons.vpn_lock_outlined,
                      text: '检测系统 VPN、代理和常见 Windows 代理客户端',
                    ),
                    const FeatureLine(
                      icon: Icons.schedule,
                      text: '当 VPN/代理开启且网络或时间命中规则时强提醒',
                    ),
                    const SizedBox(height: 22),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: background,
                      onChanged: (value) => setState(() => background = value),
                      title: const Text('启用持续后台监控'),
                      subtitle: const Text(
                        'Android 使用前台服务；Windows 驻留托盘并随登录启动。',
                      ),
                    ),
                    if (Platform.isAndroid)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: overlay,
                        onChanged: (value) => setState(() => overlay = value),
                        title: const Text('启用悬浮窗强提醒'),
                        subtitle: const Text('关闭时仍会发送高优先级通知、声音和震动。'),
                      ),
                    const SizedBox(height: 18),
                    const Text(
                      'Android 读取 Wi-Fi 名称需要定位权限；不会获取或保存位置。',
                      style: TextStyle(color: Color(0xFF626A7A)),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: saving
                              ? null
                              : widget.controller.requestPermissions,
                          child: const Text('申请系统权限'),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: saving ? null : _finish,
                          icon: saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check),
                          label: const Text('完成设置'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.controller});

  final MonitorController controller;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _destinations = [
    (Icons.dashboard_outlined, Icons.dashboard, '状态'),
    (Icons.wifi, Icons.wifi, '网络规则'),
    (Icons.schedule, Icons.schedule, '时间规则'),
    (Icons.settings_outlined, Icons.settings, '设置'),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(controller: widget.controller),
      NetworkRulesPage(controller: widget.controller),
      TimeRulesPage(controller: widget.controller),
      SettingsPage(controller: widget.controller),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('网络 VPN 警告'),
        actions: [
          IconButton(
            tooltip: '立即刷新',
            onPressed: widget.controller.refresh,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final content = IndexedStack(index: _index, children: pages);
          if (compact) return content;
          return Row(
            children: [
              NavigationRail(
                selectedIndex: _index,
                onDestinationSelected: (value) =>
                    setState(() => _index = value),
                labelType: NavigationRailLabelType.all,
                destinations: [
                  for (final item in _destinations)
                    NavigationRailDestination(
                      icon: Icon(item.$1),
                      selectedIcon: Icon(item.$2),
                      label: Text(item.$3),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: content),
            ],
          );
        },
      ),
      bottomNavigationBar: MediaQuery.sizeOf(context).width < 760
          ? NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (value) => setState(() => _index = value),
              destinations: [
                for (final item in _destinations)
                  NavigationDestination(
                    icon: Icon(item.$1),
                    selectedIcon: Icon(item.$2),
                    label: item.$3,
                  ),
              ],
            )
          : null,
    );
  }
}
