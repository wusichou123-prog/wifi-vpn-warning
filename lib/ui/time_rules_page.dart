import 'package:flutter/material.dart';

import '../models/app_config.dart';
import '../services/monitor_controller.dart';
import 'widgets.dart';

class TimeRulesPage extends StatelessWidget {
  const TimeRulesPage({super.key, required this.controller});

  final MonitorController controller;

  Future<void> _add(BuildContext context) async {
    final rule = await showDialog<TimeRule>(
      context: context,
      builder: (_) => const TimeRuleDialog(),
    );
    if (rule == null || rule.weekdays.isEmpty) return;
    await controller.saveConfig(
      controller.config.copyWith(
        timeRules: [...controller.config.timeRules, rule],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rules = controller.config.timeRules;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '特定时间',
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
        const Text('使用设备本地时间；开始时刻包含，结束时刻不包含。'),
        const SizedBox(height: 20),
        if (rules.isEmpty)
          const EmptyCard(text: '尚未添加时间规则')
        else
          Card(
            child: Column(
              children: [
                for (var index = 0; index < rules.length; index++) ...[
                  ListTile(
                    leading: const Icon(Icons.schedule),
                    title: Text(formatDays(rules[index].weekdays)),
                    subtitle: Text(
                      '${formatMinutes(rules[index].startMinutes)} - '
                      '${formatMinutes(rules[index].endMinutes)}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: rules[index].enabled,
                          onChanged: (value) async {
                            final next = [...rules];
                            next[index] = next[index].copyWith(enabled: value);
                            await controller.saveConfig(
                              controller.config.copyWith(timeRules: next),
                            );
                          },
                        ),
                        IconButton(
                          tooltip: '删除',
                          onPressed: () async {
                            final next = [...rules]..removeAt(index);
                            await controller.saveConfig(
                              controller.config.copyWith(timeRules: next),
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

class TimeRuleDialog extends StatefulWidget {
  const TimeRuleDialog({super.key});

  @override
  State<TimeRuleDialog> createState() => _TimeRuleDialogState();
}

class _TimeRuleDialogState extends State<TimeRuleDialog> {
  final Set<int> days = {1, 2, 3, 4, 5};
  TimeOfDay start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay end = const TimeOfDay(hour: 18, minute: 0);

  Future<void> _pick(bool isStart) async {
    final value = await showTimePicker(
      context: context,
      initialTime: isStart ? start : end,
    );
    if (value == null) return;
    setState(() {
      if (isStart) {
        start = value;
      } else {
        end = value;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('添加时间规则'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('时间段开始的星期'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                for (var day = 1; day <= 7; day++)
                  FilterChip(
                    label: Text(dayNames[day]!),
                    selected: days.contains(day),
                    onSelected: (selected) {
                      setState(() {
                        selected ? days.add(day) : days.remove(day);
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pick(true),
                    child: Text('开始 ${formatTime(start)}'),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('至'),
                ),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pick(false),
                    child: Text('结束 ${formatTime(end)}'),
                  ),
                ),
              ],
            ),
            if (end.hour * 60 + end.minute < start.hour * 60 + start.minute)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('该规则跨越午夜，所选星期表示时间段开始的日期。'),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: days.isEmpty
              ? null
              : () => Navigator.pop(
                  context,
                  TimeRule(
                    id: DateTime.now().microsecondsSinceEpoch.toString(),
                    weekdays: {...days},
                    startMinutes: start.hour * 60 + start.minute,
                    endMinutes: end.hour * 60 + end.minute,
                  ),
                ),
          child: const Text('保存'),
        ),
      ],
    );
  }
}

const dayNames = {
  1: '周一',
  2: '周二',
  3: '周三',
  4: '周四',
  5: '周五',
  6: '周六',
  7: '周日',
};

String formatDays(Set<int> days) {
  final sorted = days.toList()..sort();
  return sorted.map((day) => dayNames[day]).join('、');
}

String formatMinutes(int minutes) {
  final hour = (minutes ~/ 60).toString().padLeft(2, '0');
  final minute = (minutes % 60).toString().padLeft(2, '0');
  return '$hour:$minute';
}

String formatTime(TimeOfDay time) {
  return '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';
}
