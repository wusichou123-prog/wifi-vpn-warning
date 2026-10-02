import 'package:flutter/material.dart';

import '../models/app_config.dart';
import '../services/monitor_controller.dart';
import 'widgets.dart';

class NetworkRulesPage extends StatelessWidget {
  const NetworkRulesPage({super.key, required this.controller});

  final MonitorController controller;

  Future<void> _add(BuildContext context) async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => const TextInputDialog(
        title: '添加 Wi-Fi 规则',
        label: 'Wi-Fi 名称（SSID）',
        hint: '例如：Home-WiFi',
      ),
    );
    if (value == null || value.trim().isEmpty) return;
    final rules = [
      ...controller.config.networkRules,
      NetworkRule(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        ssid: value.trim(),
      ),
    ];
    await controller.saveConfig(
      controller.config.copyWith(networkRules: rules),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rules = controller.config.networkRules;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '特定 Wi-Fi',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            FilledButton.icon(
              onPressed: () => _add(context),
              icon: const Icon(Icons.add),
              label: const Text('添加规则'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text('名称采用不区分大小写的精确匹配；定位权限缺失时不会命中。'),
        const SizedBox(height: 20),
        if (rules.isEmpty)
          const EmptyCard(text: '尚未添加 Wi-Fi 规则')
        else
          Card(
            child: Column(
              children: [
                for (var index = 0; index < rules.length; index++) ...[
                  ListTile(
                    leading: const Icon(Icons.wifi),
                    title: Text(rules[index].ssid),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: rules[index].enabled,
                          onChanged: (value) async {
                            final next = [...rules];
                            next[index] = next[index].copyWith(enabled: value);
                            await controller.saveConfig(
                              controller.config.copyWith(networkRules: next),
                            );
                          },
                        ),
                        IconButton(
                          tooltip: '删除',
                          onPressed: () async {
                            final next = [...rules]..removeAt(index);
                            await controller.saveConfig(
                              controller.config.copyWith(networkRules: next),
                            );
                          },
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                  if (index != rules.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
