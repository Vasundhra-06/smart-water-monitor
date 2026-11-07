import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/alert.dart';
import '../models/sensor_reading.dart';
import '../../core/services/thing_speak_http_service.dart';

abstract class IAlertRepository {
  Future<List<AlertItem>> getAlerts();
  void markAsRead(String alertId);
  void markAllAsRead();
  Future<void> clearAllAlerts();
  bool get isCleared;
}

class AlertRepository implements IAlertRepository {
  final ThingSpeakHttpService _service = ThingSpeakHttpService.instance;
  static final Set<String> _readAlertIds = {};
  static final Set<String> _clearedAlertIds = {};
  static final Set<String> _currentAlertIds = {};
  static bool _prefsLoaded = false;

  // WiFi / connectivity tracking
  static DateTime? _lastSuccessfulFetch;
  static int _consecutiveFetchFailures = 0;
  static const int _wifiOfflineThresholdSeconds = 90; // alert after 90s no data

  static Future<void> _ensurePrefsLoaded() async {
    if (_prefsLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final read = prefs.getStringList('read_alert_ids') ?? [];
      final cleared = prefs.getStringList('cleared_alert_ids') ?? [];
      _readAlertIds.addAll(read);
      _clearedAlertIds.addAll(cleared);
      _prefsLoaded = true;
    } catch (_) {}
  }

  @override
  bool get isCleared => _clearedAlertIds.isNotEmpty;

  @override
  Future<void> clearAllAlerts() async {
    _clearedAlertIds.addAll(_currentAlertIds);
    _readAlertIds.addAll(_currentAlertIds);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('cleared_alert_ids', _clearedAlertIds.toList());
      await prefs.setStringList('read_alert_ids', _readAlertIds.toList());
    } catch (_) {}
  }

  @override
  void markAsRead(String alertId) async {
    _readAlertIds.add(alertId);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('read_alert_ids', _readAlertIds.toList());
    } catch (_) {}
  }

  @override
  void markAllAsRead() async {
    _readAlertIds.addAll(_currentAlertIds);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('read_alert_ids', _readAlertIds.toList());
    } catch (_) {}
  }

  /// Returns the overall system health status based on current alerts.
  /// 'safe'    → all clear (green icon)
  /// 'warning' → at least one WARNING severity alert (yellow icon)
  /// 'critical'→ at least one CRITICAL severity alert (red icon)
  static String computeSystemStatus(List<AlertItem> alerts) {
    if (alerts.isEmpty) return 'safe';
    final hasCritical = alerts.any((a) => a.severity == 'CRITICAL');
    if (hasCritical) return 'critical';
    final hasWarning = alerts.any((a) => a.severity == 'WARNING');
    if (hasWarning) return 'warning';
    return 'safe';
  }

  @override
  Future<List<AlertItem>> getAlerts() async {
    await _ensurePrefsLoaded();

    final now = DateTime.now();
    final List<AlertItem> alerts = [];

    // ── WiFi / Connectivity Alert ─────────────────────────────────────────────
    // Try fetching the latest reading; track success/failure for WiFi alerts.
    SensorReading reading;
    bool fetchSucceeded = false;
    try {
      reading = await _service.fetchLatestReading().timeout(const Duration(seconds: 8));
      if (!reading.isZero) {
        _lastSuccessfulFetch = now;
        _consecutiveFetchFailures = 0;
        fetchSucceeded = true;
      } else {
        _consecutiveFetchFailures++;
      }
    } catch (_) {
      _consecutiveFetchFailures++;
      reading = _service.latestCachedReading ?? SensorReading.zero();
    }

    // WiFi alert: if data has been stale for ≥ 90 s or we keep failing
    final bool wifiOffline = !fetchSucceeded &&
        (_lastSuccessfulFetch == null ||
            now.difference(_lastSuccessfulFetch!).inSeconds >= _wifiOfflineThresholdSeconds ||
            _consecutiveFetchFailures >= 3);

    if (wifiOffline) {
      final severity = (_consecutiveFetchFailures >= 6) ? 'CRITICAL' : 'WARNING';
      final staleSecs = _lastSuccessfulFetch != null
          ? now.difference(_lastSuccessfulFetch!).inSeconds
          : null;
      final staleMsg = staleSecs != null
          ? 'Last successful data: ${staleSecs ~/ 60}m ${staleSecs % 60}s ago.'
          : 'No data has been received since startup.';

      alerts.add(AlertItem(
        id: 'alert-wifi-offline-${now.minute ~/ 2}', // bucket per 2 min to avoid spam
        tankId: 'tank-main',
        deviceId: 'TANK_001',
        alertType: 'wifi',
        severity: severity,
        title: severity == 'CRITICAL'
            ? 'ESP32 Offline — No ThingSpeak Data'
            : 'WiFi Connection Weak — Data Delay',
        message: severity == 'CRITICAL'
            ? 'No data received from the ESP32 device. Check WiFi credentials on the firmware, power supply, or ThingSpeak channel. $staleMsg'
            : 'ThingSpeak feed is delayed or unreachable. $_consecutiveFetchFailures consecutive fetch failures. $staleMsg',
        detectedAt: now,
        isRead: _readAlertIds.contains('alert-wifi-offline-${now.minute ~/ 2}'),
        isResolved: false,
      ));
    }

    // In standby / zero mode — only WiFi alert is relevant
    if (reading.isZero || _service.isResetMode) {
      _currentAlertIds.clear();
      for (final a in alerts) {
        _currentAlertIds.add(a.id);
      }
      return alerts.where((a) => !_clearedAlertIds.contains(a.id)).toList();
    }

    // ── Power Supply Alert ────────────────────────────────────────────────────
    // Detect abnormally low voltage proxy: water-level field is reused for
    // supply voltage on some firmware builds (field5). We flag power issues
    // when the reading timestamp is significantly stale (device went offline).
    final dataAgeMinutes = now.difference(reading.timestamp.toLocal()).inMinutes;
    if (dataAgeMinutes >= 10) {
      alerts.add(AlertItem(
        id: 'alert-power-stale-${reading.id}',
        tankId: reading.tankId,
        deviceId: reading.deviceId,
        alertType: 'power',
        severity: dataAgeMinutes >= 30 ? 'CRITICAL' : 'WARNING',
        title: dataAgeMinutes >= 30
            ? 'Power Failure — ESP32 May Be Offline'
            : 'Power Issue — Stale Sensor Data (${dataAgeMinutes}m old)',
        message: dataAgeMinutes >= 30
            ? 'No new readings for ${dataAgeMinutes} minutes. The ESP32 device may have lost mains power or battery backup. Check 5V power supply and USB connection.'
            : 'Sensor data is ${dataAgeMinutes} minutes old. Possible power fluctuation or intermittent connectivity. Verify ESP32 power supply.',
        detectedAt: reading.timestamp,
        isRead: _readAlertIds.contains('alert-power-stale-${reading.id}'),
        isResolved: false,
      ));
    }

    // ── Device / Hardware Sensor Alerts ───────────────────────────────────────

    // Temperature probe disconnected (DS18B20 returns -127°C when wire off)
    final isProbeDisconnected = reading.isProbeDisconnected ||
        (reading.rawTemperature != null && reading.rawTemperature! <= -50.0) ||
        reading.temperature <= -100.0;

    if (isProbeDisconnected) {
      alerts.add(AlertItem(
        id: 'alert-probe-temp-disconnected-${reading.id}',
        tankId: reading.tankId,
        deviceId: reading.deviceId,
        alertType: 'device',
        severity: 'WARNING',
        title: 'Temperature Sensor Disconnected',
        message:
            'DS18B20 digital probe returned ${reading.rawTemperature?.toStringAsFixed(1) ?? '-127.0'}°C — wire may be loose. '
            'Check 4.7kΩ pull-up resistor on GPIO 32.',
        parameter: 'temperature',
        value: reading.rawTemperature ?? -127.0,
        threshold: 0.0,
        detectedAt: reading.timestamp,
        isRead: _readAlertIds.contains('alert-probe-temp-disconnected-${reading.id}'),
        isResolved: false,
      ));
    }

    // pH sensor out of measurable range → likely uncalibrated or disconnected
    if (reading.ph < 4.0 || reading.ph > 11.5) {
      alerts.add(AlertItem(
        id: 'alert-ph-calibration-${reading.id}',
        tankId: reading.tankId,
        deviceId: reading.deviceId,
        alertType: 'device',
        severity: 'WARNING',
        title: 'pH Sensor Needs Calibration (${reading.ph.toStringAsFixed(1)})',
        message:
            'Analog pH electrode output (${reading.ph.toStringAsFixed(1)}) is outside the measurable range of 4.0–11.5. '
            'Recalibrate the probe using pH 4.01 and pH 7.00 buffer solutions.',
        parameter: 'ph_calibration',
        value: reading.ph,
        threshold: 8.5,
        detectedAt: reading.timestamp,
        isRead: _readAlertIds.contains('alert-ph-calibration-${reading.id}'),
        isResolved: false,
      ));
    }

    // ── Water Quality / Cleaning Alerts ───────────────────────────────────────

    // pH outside BIS drinking water range
    if (reading.ph >= 4.0 && reading.ph <= 11.5) {
      if (reading.ph < 6.5 || reading.ph > 8.5) {
        alerts.add(AlertItem(
          id: 'alert-ph-threshold-${reading.id}',
          tankId: reading.tankId,
          deviceId: reading.deviceId,
          alertType: 'cleaning',
          severity: 'WARNING',
          title: 'pH Outside BIS Safe Range (${reading.ph.toStringAsFixed(2)})',
          message: reading.ph < 6.5
              ? 'Acidic water detected (pH ${reading.ph.toStringAsFixed(2)} < 6.5 BIS limit). '
                'Consider dosing or tank inspection.'
              : 'Alkaline water detected (pH ${reading.ph.toStringAsFixed(2)} > 8.5 BIS limit). '
                'Check for contamination or mineral buildup.',
          parameter: 'ph',
          value: reading.ph,
          threshold: reading.ph < 6.5 ? 6.5 : 8.5,
          detectedAt: reading.timestamp,
          isRead: _readAlertIds.contains('alert-ph-threshold-${reading.id}'),
          isResolved: false,
        ));
      }
    }

    // TDS elevated
    if (reading.tds > 500) {
      alerts.add(AlertItem(
        id: 'alert-tds-threshold-${reading.id}',
        tankId: reading.tankId,
        deviceId: reading.deviceId,
        alertType: 'cleaning',
        severity: reading.tds > 1000 ? 'CRITICAL' : 'WARNING',
        title: reading.tds > 1000
            ? 'TDS Critically High — Water Unsafe (${reading.tds.toStringAsFixed(0)} ppm)'
            : 'TDS Above BIS Limit (${reading.tds.toStringAsFixed(0)} ppm)',
        message: 'TDS concentration is ${reading.tds.toStringAsFixed(0)} ppm (BIS limit: 500 ppm). '
            'Filter maintenance or tank flushing is recommended.',
        parameter: 'tds',
        value: reading.tds,
        threshold: 500.0,
        detectedAt: reading.timestamp,
        isRead: _readAlertIds.contains('alert-tds-threshold-${reading.id}'),
        isResolved: false,
      ));
    }

    // Turbidity high
    if (reading.turbidity > 2.5) {
      alerts.add(AlertItem(
        id: 'alert-turbidity-${reading.id}',
        tankId: reading.tankId,
        deviceId: reading.deviceId,
        alertType: 'cleaning',
        severity: reading.turbidity > 4.0 ? 'CRITICAL' : 'WARNING',
        title: reading.turbidity > 4.0
            ? 'Turbidity Critical — Visually Cloudy (${reading.turbidity.toStringAsFixed(2)} NTU)'
            : 'Turbidity Elevated (${reading.turbidity.toStringAsFixed(2)} NTU)',
        message: 'Water turbidity is ${reading.turbidity.toStringAsFixed(2)} NTU (WHO guideline: < 1 NTU, BIS max: 1 NTU). '
            'Tank cleaning or filter inspection is advised.',
        parameter: 'turbidity',
        value: reading.turbidity,
        threshold: 2.5,
        detectedAt: reading.timestamp,
        isRead: _readAlertIds.contains('alert-turbidity-${reading.id}'),
        isResolved: false,
      ));
    }

    // Water quality score low
    if (reading.waterQualityScore < 50) {
      alerts.add(AlertItem(
        id: 'alert-score-low-${reading.id}',
        tankId: reading.tankId,
        deviceId: reading.deviceId,
        alertType: 'cleaning',
        severity: reading.waterQualityScore < 25 ? 'CRITICAL' : 'WARNING',
        title: 'Low Water Quality Score (${reading.waterQualityScore}%)',
        message: 'Overall Water Quality Index dropped to ${reading.waterQualityScore}%. '
            'The water may be unsafe for drinking. Inspect the tank and run a full cleaning cycle.',
        parameter: 'quality_score',
        value: reading.waterQualityScore.toDouble(),
        threshold: 50.0,
        detectedAt: reading.timestamp,
        isRead: _readAlertIds.contains('alert-score-low-${reading.id}'),
        isResolved: false,
      ));
    }

    // ── Track & filter cleared alerts ─────────────────────────────────────────
    _currentAlertIds.clear();
    for (final a in alerts) {
      _currentAlertIds.add(a.id);
    }

    return alerts.where((a) => !_clearedAlertIds.contains(a.id)).toList();
  }
}
