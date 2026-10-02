import 'package:flutter/material.dart';

import '../models/detection_snapshot.dart';
import '../services/monitor_controller.dart';
import 'widgets.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.controller});

  final MonitorController controller;

  @override
  Widget build(BuildContext context) {
    final snapshot =
        controller.snapshot ?? DetectionSnapshot.unavailable('正在读取系统状态');
    final now = DateTime.now();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (controller.error != null)
          MessageCard(
            icon: Icons.error_outline,
            color: Colors.red,
            title: '检测异常',
            body: controller.error!,
          ),
        if (snapshot.error != null)
          MessageCard(
            icon: Icons.warning_amber,
            color: Colors.orange,
            title: '部分检测不可用',
            body: snapshot.error!,
          ),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            MetricCard(
              icon: Icons.wifi,
              label: '当前 Wi-Fi',
              value: snapshot.wifiAvailable
                  ? (snapshot.wifiSsid ?? '隐藏网络')
                  : '不可用',
              detail: snapshot.wifiError ?? 'VPN 下方的实际连接网络',
            ),
            MetricCard(
              icon: snapshot.vpnActive
                  ? Icons.vpn_lock
                  : Icons.vpn_lock_outlined,
              label: 'VPN',
              value: snapshot.vpnActive ? '已开启' : '未检测到',
              detail: snapshot.vpnSources.isEmpty
                  ? '系统未报告 VPN 网络'
                  : snapshot.vpnSources.join('、'),
              emphasized: snapshot.vpnActive,
            ),
            MetricCard(
              icon: Icons.swap_horiz,
              label: '系统代理',
              value: snapshot.proxyActive ? '已开启' : '未检测到',
              detail: snapshot.proxySources.isEmpty
                  ? '系统未报告代理'
                  : snapshot.proxySources.join('、'),
              emphasized: snapshot.proxyActive,
            ),
            MetricCard(
              icon: Icons.schedule,
              label: '设备本地时间',
              value:
                  '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
              detail:
                  '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
            ),
          ],
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('监控状态', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      controller.config.backgroundMonitoring
                          ? Icons.check_circle
                          : Icons.pause_circle_outline,
                      color: controller.config.backgroundMonitoring
                          ? Colors.green
                          : Colors.orange,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      controller.config.backgroundMonitoring
                          ? '持续后台监控已启用'
                          : '仅应用前台运行期间监控',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '告警条件：VPN 或代理开启，且当前 Wi-Fi 命中网络规则，或当前时间命中时间规则。',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final color = emphasized
        ? Theme.of(context).colorScheme.primary
        : Colors.black87;
    return SizedBox(
      width: 300,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color),
                  const SizedBox(width: 10),
                  Text(label, style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(color: color, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                detail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
