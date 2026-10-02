import 'dart:convert';

class NetworkRule {
  const NetworkRule({
    required this.id,
    required this.ssid,
    this.enabled = true,
  });

  final String id;
  final String ssid;
  final bool enabled;

  NetworkRule copyWith({String? id, String? ssid, bool? enabled}) {
    return NetworkRule(
      id: id ?? this.id,
      ssid: ssid ?? this.ssid,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, Object?> toJson() => {'id': id, 'ssid': ssid, 'enabled': enabled};

  factory NetworkRule.fromJson(Map<String, dynamic> json) {
    return NetworkRule(
      id: json['id'] as String? ?? '',
      ssid: json['ssid'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}

class TimeRule {
  const TimeRule({
    required this.id,
    required this.weekdays,
    required this.startMinutes,
    required this.endMinutes,
    this.enabled = true,
  });

  final String id;
  final Set<int> weekdays;
  final int startMinutes;
  final int endMinutes;
  final bool enabled;

  TimeRule copyWith({
    String? id,
    Set<int>? weekdays,
    int? startMinutes,
    int? endMinutes,
    bool? enabled,
  }) {
    return TimeRule(
      id: id ?? this.id,
      weekdays: weekdays ?? this.weekdays,
      startMinutes: startMinutes ?? this.startMinutes,
      endMinutes: endMinutes ?? this.endMinutes,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'weekdays': (weekdays.toList()..sort()),
    'startMinutes': startMinutes,
    'endMinutes': endMinutes,
    'enabled': enabled,
  };

  factory TimeRule.fromJson(Map<String, dynamic> json) {
    final rawWeekdays = json['weekdays'] as List<dynamic>? ?? const [];
    return TimeRule(
      id: json['id'] as String? ?? '',
      weekdays: rawWeekdays.map((value) => value as int).toSet(),
      startMinutes: json['startMinutes'] as int? ?? 0,
      endMinutes: json['endMinutes'] as int? ?? 0,
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}

class AppConfig {
  const AppConfig({
    this.schemaVersion = 1,
    this.backgroundMonitoring = false,
    this.startAtLogin = false,
    this.overlayEnabled = false,
    this.firstRunCompleted = false,
    this.networkRules = const [],
    this.timeRules = const [],
    this.proxyProcessPatterns = defaultProxyProcessPatterns,
  });

  static const List<String> defaultProxyProcessPatterns = [
    'clash',
    'mihomo',
    'v2ray',
    'xray',
    'sing-box',
    'wireguard',
    'openvpn',
    'tailscale',
    'zerotier',
    'softether',
    'proxifier',
  ];

  final int schemaVersion;
  final bool backgroundMonitoring;
  final bool startAtLogin;
  final bool overlayEnabled;
  final bool firstRunCompleted;
  final List<NetworkRule> networkRules;
  final List<TimeRule> timeRules;
  final List<String> proxyProcessPatterns;

  AppConfig copyWith({
    int? schemaVersion,
    bool? backgroundMonitoring,
    bool? startAtLogin,
    bool? overlayEnabled,
    bool? firstRunCompleted,
    List<NetworkRule>? networkRules,
    List<TimeRule>? timeRules,
    List<String>? proxyProcessPatterns,
  }) {
    return AppConfig(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      backgroundMonitoring: backgroundMonitoring ?? this.backgroundMonitoring,
      startAtLogin: startAtLogin ?? this.startAtLogin,
      overlayEnabled: overlayEnabled ?? this.overlayEnabled,
      firstRunCompleted: firstRunCompleted ?? this.firstRunCompleted,
      networkRules: networkRules ?? this.networkRules,
      timeRules: timeRules ?? this.timeRules,
      proxyProcessPatterns: proxyProcessPatterns ?? this.proxyProcessPatterns,
    );
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'backgroundMonitoring': backgroundMonitoring,
    'startAtLogin': startAtLogin,
    'overlayEnabled': overlayEnabled,
    'firstRunCompleted': firstRunCompleted,
    'networkRules': networkRules.map((rule) => rule.toJson()).toList(),
    'timeRules': timeRules.map((rule) => rule.toJson()).toList(),
    'proxyProcessPatterns': proxyProcessPatterns,
  };

  String encode() => jsonEncode(toJson());

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    final rawNetworks = json['networkRules'] as List<dynamic>? ?? const [];
    final rawTimes = json['timeRules'] as List<dynamic>? ?? const [];
    final rawPatterns =
        json['proxyProcessPatterns'] as List<dynamic>? ?? const [];
    return AppConfig(
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      backgroundMonitoring: json['backgroundMonitoring'] as bool? ?? false,
      startAtLogin: json['startAtLogin'] as bool? ?? false,
      overlayEnabled: json['overlayEnabled'] as bool? ?? false,
      firstRunCompleted: json['firstRunCompleted'] as bool? ?? false,
      networkRules: rawNetworks
          .map(
            (value) =>
                NetworkRule.fromJson(Map<String, dynamic>.from(value as Map)),
          )
          .toList(),
      timeRules: rawTimes
          .map(
            (value) =>
                TimeRule.fromJson(Map<String, dynamic>.from(value as Map)),
          )
          .toList(),
      proxyProcessPatterns: rawPatterns.isEmpty
          ? defaultProxyProcessPatterns
          : rawPatterns.map((value) => value.toString()).toList(),
    );
  }

  static AppConfig decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const AppConfig();
    }
    try {
      return AppConfig.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return const AppConfig();
    }
  }
}
