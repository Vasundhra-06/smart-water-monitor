import 'package:shared_preferences/shared_preferences.dart';
import '../models/alert.dart';
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

  @override
  Future<List<AlertItem>> getAlerts() async {
    await _ensurePrefsLoaded();

    final reading = await _service.fetchLatestReading();
    final isStandby = reading.isZero || _service.isResetMode;

    // In standby mode, no telemetry alerts are active
    if (isStandby) {
      _currentAlertIds.clear();
      return [];
    }

    final List<AlertItem> alerts = [];

    // 1. Hardware & Sensor Connectivity Diagnosis
    final isProbeDisconnected = reading.isProbeDisconnected ||
        (reading.rawTemperature != null && reading.rawTemperature! <= -50.0) ||
        reading.temperature <= -100.0;

    if (isProbeDisconnected) {
      alerts.add(
        AlertItem(
          id: 'alert-probe-temp-disconnected-${reading.id}',
          tankId: reading.tankId,
          deviceId: reading.deviceId,
          alertType: 'device',
          severity: 'CRITICAL',
          title: 'Temperature Sensor Disconnected (-127°C)',
          message: 'Hardware Error: DS18B20 digital probe returned -127.0°C. Check 4.7kΩ pull-up resistor and GPIO 32 wiring.',
          parameter: 'temperature',
          value: reading.rawTemperature ?? -127.0,
          threshold: 0.0,
          detectedAt: reading.timestamp,
          isRead: _readAlertIds.contains('alert-probe-temp-disconnected-${reading.id}'),
          isResolved: false,
        ),
      );
    }

    // 2. Sensor Calibration & Out of Range Alerts
    if (reading.ph < 4.0 || reading.ph > 11.5) {
      alerts.add(
        AlertItem(
          id: 'alert-ph-calibration-${reading.id}',
          tankId: reading.tankId,
          deviceId: reading.deviceId,
          alertType: 'device',
          severity: 'WARNING',
          title: 'Sensor Calibration Required: pH Probe Out of Range (${reading.ph.toStringAsFixed(1)})',
          message: 'Hardware Diagnosis: Analog pH electrode output (${reading.ph.toStringAsFixed(1)}) exceeds potable bounds. Recalibrate probe with standard pH 4.01 and pH 7.00 buffers.',
          parameter: 'ph_calibration',
          value: reading.ph,
          threshold: 8.5,
          detectedAt: reading.timestamp,
          isRead: _readAlertIds.contains('alert-ph-calibration-${reading.id}'),
          isResolved: false,
        ),
      );
    }

    // 3. Water Quality Deterioration & Chemical Risk
    if (reading.waterQualityScore < 50) {
      alerts.add(
        AlertItem(
          id: 'alert-score-critical-${reading.id}',
          tankId: reading.tankId,
          deviceId: reading.deviceId,
          alertType: 'critical',
          severity: 'CRITICAL',
          title: 'Critical Water Quality Alert (${reading.waterQualityScore}%)',
          message: 'Overall Water Quality Score dropped to ${reading.waterQualityScore}%. Water is unsafe for drinking. Technical inspection required.',
          parameter: 'quality_score',
          value: reading.waterQualityScore.toDouble(),
          threshold: 50.0,
          detectedAt: reading.timestamp,
          isRead: _readAlertIds.contains('alert-score-critical-${reading.id}'),
          isResolved: false,
        ),
      );
    }

    // pH Acceptable Limit Alert (6.5 - 8.5)
    if (reading.ph < 6.5 || reading.ph > 8.5) {
      alerts.add(
        AlertItem(
          id: 'alert-ph-threshold-${reading.id}',
          tankId: reading.tankId,
          deviceId: reading.deviceId,
          alertType: 'critical',
          severity: 'CRITICAL',
          title: 'pH Level Outside BIS Acceptable Range (${reading.ph.toStringAsFixed(2)})',
          message: reading.ph < 6.5
              ? 'Acidic water detected (pH ${reading.ph.toStringAsFixed(2)} < 6.5).'
              : 'Alkaline water detected (pH ${reading.ph.toStringAsFixed(2)} > 8.5).',
          parameter: 'ph',
          value: reading.ph,
          threshold: reading.ph < 6.5 ? 6.5 : 8.5,
          detectedAt: reading.timestamp,
          isRead: _readAlertIds.contains('alert-ph-threshold-${reading.id}'),
          isResolved: false,
        ),
      );
    }

    // TDS Limit Alert (> 500 ppm)
    if (reading.tds > 500) {
      alerts.add(
        AlertItem(
          id: 'alert-tds-threshold-${reading.id}',
          tankId: reading.tankId,
          deviceId: reading.deviceId,
          alertType: 'critical',
          severity: reading.tds > 2000 ? 'CRITICAL' : 'WARNING',
          title: reading.tds > 2000
              ? 'TDS Exceeds BIS Permissible Limit (${reading.tds.toStringAsFixed(0)} ppm)'
              : 'TDS Above BIS Acceptable Limit (${reading.tds.toStringAsFixed(0)} ppm)',
          message: 'TDS concentration is elevated (${reading.tds.toStringAsFixed(0)} ppm). Filter maintenance recommended.',
          parameter: 'tds',
          value: reading.tds,
          threshold: 500.0,
          detectedAt: reading.timestamp,
          isRead: _readAlertIds.contains('alert-tds-threshold-${reading.id}'),
          isResolved: false,
        ),
      );
    }

    // Track active alert IDs and filter out cleared alerts
    _currentAlertIds.clear();
    for (final a in alerts) {
      _currentAlertIds.add(a.id);
    }

    return alerts.where((a) => !_clearedAlertIds.contains(a.id)).toList();
  }
}
