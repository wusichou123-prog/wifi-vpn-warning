import 'package:flutter_test/flutter_test.dart';
import 'package:wifi_warning/models/app_config.dart';
import 'package:wifi_warning/models/detection_snapshot.dart';
import 'package:wifi_warning/services/rule_engine.dart';

void main() {
  const engine = RuleEngine();
  const config = AppConfig(
    networkRules: [NetworkRule(id: 'wifi', ssid: 'Office-WiFi')],
    timeRules: [
      TimeRule(
        id: 'work',
        weekdays: {1, 2, 3, 4, 5},
        startMinutes: 9 * 60,
        endMinutes: 18 * 60,
      ),
    ],
  );

  DetectionSnapshot snapshot({
    bool vpn = true,
    bool proxy = false,
    String? ssid = 'Other-WiFi',
  }) {
    return DetectionSnapshot(
      timestamp: DateTime(2026, 9, 30, 10),
      wifiSsid: ssid,
      wifiAvailable: ssid != null,
      vpnActive: vpn,
      proxyActive: proxy,
    );
  }

  test('does not alert without VPN or proxy', () {
    final result = engine.evaluate(
      config,
      snapshot(vpn: false, ssid: 'Office-WiFi'),
      now: DateTime(2026, 9, 30, 10),
    );
    expect(result.shouldAlert, isFalse);
  });

  test('alerts when protected link and network match', () {
    final result = engine.evaluate(
      config,
      snapshot(ssid: 'office-wifi'),
      now: DateTime(2026, 9, 30, 20),
    );
    expect(result.shouldAlert, isTrue);
    expect(result.networkMatched, isTrue);
    expect(result.timeMatched, isFalse);
  });

  test('alerts when protected link and time match', () {
    final result = engine.evaluate(
      config,
      snapshot(),
      now: DateTime(2026, 9, 30, 10),
    );
    expect(result.shouldAlert, isTrue);
    expect(result.networkMatched, isFalse);
    expect(result.timeMatched, isTrue);
  });

  test('supports overnight and start-day weekday semantics', () {
    const overnight = AppConfig(
      timeRules: [
        TimeRule(
          id: 'night',
          weekdays: {1},
          startMinutes: 23 * 60,
          endMinutes: 2 * 60,
        ),
      ],
    );
    expect(
      engine
          .evaluate(
            overnight,
            snapshot(ssid: null),
            now: DateTime(2026, 9, 28, 23, 30),
          )
          .shouldAlert,
      isTrue,
    );
    expect(
      engine
          .evaluate(
            overnight,
            snapshot(ssid: null),
            now: DateTime(2026, 9, 29, 1, 30),
          )
          .shouldAlert,
      isTrue,
    );
    expect(
      engine
          .evaluate(
            overnight,
            snapshot(ssid: null),
            now: DateTime(2026, 9, 29, 2),
          )
          .shouldAlert,
      isFalse,
    );
  });

  test('accepts proxy as protected link', () {
    final result = engine.evaluate(
      config,
      snapshot(vpn: false, proxy: true, ssid: null),
      now: DateTime(2026, 9, 30, 10),
    );
    expect(result.shouldAlert, isTrue);
  });
}
