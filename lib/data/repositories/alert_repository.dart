import '../models/alert.dart';
import '../../core/services/thing_speak_http_service.dart';

abstract class IAlertRepository {
  Future<List<AlertItem>> getAlerts();
}

class AlertRepository implements IAlertRepository {
  final ThingSpeakHttpService _service = ThingSpeakHttpService.instance;

  @override
  Future<List<AlertItem>> getAlerts() async {
    final reading = await _service.fetchLatestReading();
    final List<AlertItem> alerts = [];
    final now = DateTime.now();

    // 1. Water Quality Score Alert
    if (reading.waterQualityScore < 50) {
      alerts.add(
        AlertItem(
          id: 'alert-score-${reading.id}',
          tankId: reading.tankId,
          deviceId: reading.deviceId,
          alertType: 'critical',
          severity: reading.waterQualityScore < 25 ? 'CRITICAL' : 'WARNING',
          title: '🔴 Water Quality Score Low (${reading.waterQualityScore}%)',
          message: 'Overall Water Quality Score dropped to ${reading.waterQualityScore}% (${reading.qualityZone}). Inspection recommended.',
          parameter: 'quality_score',
          value: reading.waterQualityScore.toDouble(),
          threshold: 50.0,
          detectedAt: reading.timestamp,
          isRead: false,
          isResolved: false,
        ),
      );
    }

    // 2. pH Threshold Alert (6.5 - 8.5)
    if (reading.ph < 6.5 || reading.ph > 8.5) {
      alerts.add(
        AlertItem(
          id: 'alert-ph-${reading.id}',
          tankId: reading.tankId,
          deviceId: reading.deviceId,
          alertType: 'device',
          severity: (reading.ph < 5.5 || reading.ph > 9.5) ? 'CRITICAL' : 'WARNING',
          title: '🧪 pH Level Deviation (${reading.ph})',
          message: reading.ph < 6.5
              ? 'pH level is acidic (${reading.ph}). Ideal range is 6.5 – 8.5.'
              : 'pH level is alkaline (${reading.ph}). Ideal range is 6.5 – 8.5.',
          parameter: 'ph',
          value: reading.ph,
          threshold: reading.ph < 6.5 ? 6.5 : 8.5,
          detectedAt: reading.timestamp,
          isRead: false,
          isResolved: false,
        ),
      );
    }

    // 3. TDS Threshold Alert (> 500 ppm)
    if (reading.tds > 500) {
      alerts.add(
        AlertItem(
          id: 'alert-tds-${reading.id}',
          tankId: reading.tankId,
          deviceId: reading.deviceId,
          alertType: 'cleaning',
          severity: reading.tds > 1000 ? 'CRITICAL' : 'WARNING',
          title: '🧂 Elevated Total Dissolved Solids (${reading.tds.toStringAsFixed(0)} ppm)',
          message: 'TDS concentration exceeds recommended drinking threshold (500 ppm). Tank scrubbing and filtration check suggested.',
          parameter: 'tds',
          value: reading.tds,
          threshold: 500.0,
          detectedAt: reading.timestamp,
          isRead: false,
          isResolved: false,
        ),
      );
    }

    // 4. Temperature Alert (20 - 30 °C)
    if (reading.temperature < 20.0 || reading.temperature > 30.0) {
      alerts.add(
        AlertItem(
          id: 'alert-temp-${reading.id}',
          tankId: reading.tankId,
          deviceId: reading.deviceId,
          alertType: 'device',
          severity: 'WARNING',
          title: '🌡️ Temperature Warning (${reading.temperature.toStringAsFixed(1)} °C)',
          message: 'Water temperature (${reading.temperature.toStringAsFixed(1)} °C) is outside the 20 – 30 °C optimal zone.',
          parameter: 'temperature',
          value: reading.temperature,
          threshold: reading.temperature < 20.0 ? 20.0 : 30.0,
          detectedAt: reading.timestamp,
          isRead: false,
          isResolved: false,
        ),
      );
    }

    // Default status info alert if everything is normal
    if (alerts.isEmpty) {
      alerts.add(
        AlertItem(
          id: 'alert-status-normal',
          tankId: reading.tankId,
          deviceId: reading.deviceId,
          alertType: 'device',
          severity: 'INFO',
          title: '✓ All Parameters Operating Normally',
          message: 'ThingSpeak telemetry telemetry reports optimal TDS (${reading.tds.toStringAsFixed(0)} ppm), pH (${reading.ph}), and Temperature (${reading.temperature.toStringAsFixed(1)} °C).',
          parameter: 'system',
          value: reading.waterQualityScore.toDouble(),
          threshold: 100.0,
          detectedAt: now,
          isRead: true,
          isResolved: true,
        ),
      );
    }

    return alerts;
  }
}
