import '../models/app_config.dart';
import '../models/detection_snapshot.dart';

class RuleEvaluation {
  const RuleEvaluation({
    required this.protectedLinkActive,
    required this.networkMatched,
    required this.timeMatched,
    this.networkRuleIds = const [],
    this.timeRuleIds = const [],
  });

  final bool protectedLinkActive;
  final bool networkMatched;
  final bool timeMatched;
  final List<String> networkRuleIds;
  final List<String> timeRuleIds;

  bool get shouldAlert =>
      protectedLinkActive && (networkMatched || timeMatched);

  List<String> get reasons => [
    if (networkMatched) '当前 Wi-Fi 命中网络规则',
    if (timeMatched) '当前时间命中时间规则',
  ];
}

class RuleEngine {
  const RuleEngine();

  RuleEvaluation evaluate(
    AppConfig config,
    DetectionSnapshot snapshot, {
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final networkIds = config.networkRules
        .where(
          (rule) =>
              rule.enabled &&
              snapshot.wifiAvailable &&
              snapshot.wifiSsid != null &&
              rule.ssid.trim().isNotEmpty &&
              rule.ssid.trim().toLowerCase() ==
                  snapshot.wifiSsid!.trim().toLowerCase(),
        )
        .map((rule) => rule.id)
        .toList();

    final timeIds = config.timeRules
        .where((rule) => rule.enabled && _matchesTime(rule, current))
        .map((rule) => rule.id)
        .toList();

    return RuleEvaluation(
      protectedLinkActive: snapshot.protectedLinkActive,
      networkMatched: networkIds.isNotEmpty,
      timeMatched: timeIds.isNotEmpty,
      networkRuleIds: networkIds,
      timeRuleIds: timeIds,
    );
  }

  bool _matchesTime(TimeRule rule, DateTime now) {
    final minute = now.hour * 60 + now.minute;
    final currentDay = now.weekday;
    final previousDay = currentDay == DateTime.monday
        ? DateTime.sunday
        : currentDay - 1;

    if (rule.startMinutes == rule.endMinutes) {
      return rule.weekdays.contains(currentDay);
    }
    if (rule.startMinutes < rule.endMinutes) {
      return rule.weekdays.contains(currentDay) &&
          minute >= rule.startMinutes &&
          minute < rule.endMinutes;
    }
    return (rule.weekdays.contains(currentDay) &&
            minute >= rule.startMinutes) ||
        (rule.weekdays.contains(previousDay) && minute < rule.endMinutes);
  }
}
