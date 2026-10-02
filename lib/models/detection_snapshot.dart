class DetectionSnapshot {
  const DetectionSnapshot({
    required this.timestamp,
    this.wifiSsid,
    this.wifiAvailable = false,
    this.wifiError,
    this.vpnActive = false,
    this.vpnSources = const [],
    this.proxyActive = false,
    this.proxySources = const [],
    this.backgroundMonitoring = false,
    this.error,
  });

  final DateTime timestamp;
  final String? wifiSsid;
  final bool wifiAvailable;
  final String? wifiError;
  final bool vpnActive;
  final List<String> vpnSources;
  final bool proxyActive;
  final List<String> proxySources;
  final bool backgroundMonitoring;
  final String? error;

  bool get protectedLinkActive => vpnActive || proxyActive;

  factory DetectionSnapshot.fromMap(Map<dynamic, dynamic> map) {
    List<String> strings(String key) {
      final raw = map[key] as List<dynamic>? ?? const [];
      return raw.map((value) => value.toString()).toList();
    }

    return DetectionSnapshot(
      timestamp: map['timestamp'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int)
          : DateTime.now(),
      wifiSsid: map['wifiSsid']?.toString(),
      wifiAvailable: map['wifiAvailable'] as bool? ?? false,
      wifiError: map['wifiError']?.toString(),
      vpnActive: map['vpnActive'] as bool? ?? false,
      vpnSources: strings('vpnSources'),
      proxyActive: map['proxyActive'] as bool? ?? false,
      proxySources: strings('proxySources'),
      backgroundMonitoring: map['backgroundMonitoring'] as bool? ?? false,
      error: map['error']?.toString(),
    );
  }

  static DetectionSnapshot unavailable([String? error]) {
    return DetectionSnapshot(
      timestamp: DateTime.now(),
      wifiError: error,
      error: error,
    );
  }
}
