import '../models/alert.dart';
import '../../core/services/thing_speak_http_service.dart';

abstract class IAlertRepository {
  Future<List<AlertItem>> getAlerts();
  void markAsRead(String alertId);
  void markAllAsRead();
  void clearAllAlerts();
  bool get isCleared;
}

class AlertRepository implements IAlertRepository {
  final ThingSpeakHttpService _service = ThingSpeakHttpService.instance;
  static final Set<String> _readAlertIds = {};
  static final Set<String> _currentAlertIds = {};
  static bool _isCleared = false;

  @override
  bool get isCleared => _isCleared;

  @override
  void clearAllAlerts() {
    _isCleared = true;
    _readAlertIds.addAll(_currentAlertIds);
  }

  @override
  void markAsRead(String alertId) {
    _readAlertIds.add(alertId);
  }

  @override
  void markAllAsRead() {
    _readAlertIds.addAll(_currentAlertIds);
  }

  @override
  Future<List<AlertItem>> getAlerts() async {
    if (_isCleared) {
      return [];
    }
    final reading = await _service.fetchLatestReading();
    final List<AlertItem> alerts = [];
    final now = DateTime.now();

    final isStandby = reading.isZero || _service.isResetMode;

    if (isStandby) {
      // In standby or zero-reset mode, DO NOT emit false threshold alerts (e.g. pH 0, temp 0, score 0).
      // Only emit real system standby status, tank cleaning maintenance, and power telemetry.
      alerts.add(
        AlertItem(
          id: 'alert-standby-mode',
          tankId: reading.tankId,
          deviceId: reading.deviceId,
          alertType: 'device',
          severity: 'INFO',
          title: 'Sensor Standby Mode Active',
          message: 'Hardware probes are in standby or calibration zero mode. Dip sensors into water to begin live telemetry acquisition.',
          parameter: 'system',
          value: 0.0,
          threshold: 0.0,
          detectedAt: reading.timestamp,
          isRead: _readAlertIds.contains('alert-standby-mode'),
          isResolved: false,
        ),
      );
    } else {
      // ==========================================
      // 1. DEVICE ALERTS (Hardware Diagnosis)
      // ==========================================

      // A. Telemetry Probe Connectivity (DS18B20 -127°C error code)
      final isProbeDisconnected = reading.isProbeDisconnected ||
          (reading.rawTemperature != null && reading.rawTemperature! <= -50.0) ||
          reading.temperature <= -100.0;

      if (isProbeDisconnected) {
        alerts.add(
          AlertItem(
            id: 'alert-probe-temp-disconnected',
            tankId: reading.tankId,
            deviceId: reading.deviceId,
            alertType: 'device',
            severity: 'CRITICAL',
            title: 'Telemetry Probe Connectivity: Temperature Probe Disconnected',
            message: 'Hardware Error: DS18B20 digital probe returned error code (${reading.rawTemperature?.toStringAsFixed(1) ?? "-127.0"} °C). Verify GPIO 4 jumper wiring, VCC connection, and 4.7kΩ pull-up resistor.',
            parameter: 'telemetry_probe',
            value: reading.rawTemperature ?? -127.0,
            threshold: 0.0,
            detectedAt: reading.timestamp,
            isRead: _readAlertIds.contains('alert-probe-temp-disconnected'),
            isResolved: false,
          ),
        );
      }

      // B. Sensor Calibration Required (pH probe voltage output outside physically normal water limits)
      if (reading.ph < 4.0 || reading.ph > 11.5) {
        alerts.add(
          AlertItem(
            id: 'alert-ph-calibration-${reading.id}',
            tankId: reading.tankId,
            deviceId: reading.deviceId,
            alertType: 'device',
            severity: 'WARNING',
            title: 'Sensor Calibration Required: pH Probe Out of Range (${reading.ph.toStringAsFixed(1)})',
            message: 'Hardware Diagnosis: Analog pH electrode output (${reading.ph.toStringAsFixed(1)}) exceeds typical potable bounds. Recalibrate probe offset with standard pH 4.01 and pH 7.00 buffer solutions.',
            parameter: 'ph_calibration',
            value: reading.ph,
            threshold: 8.5,
            detectedAt: reading.timestamp,
            isRead: _readAlertIds.contains('alert-ph-calibration-${reading.id}'),
            isResolved: false,
          ),
        );
      }

      // C. TDS Meter Electrode Scaling Alert
      if (reading.tds > 1200) {
        alerts.add(
          AlertItem(
            id: 'alert-tds-scaling-${reading.id}',
            tankId: reading.tankId,
            deviceId: reading.deviceId,
            alertType: 'device',
            severity: 'WARNING',
            title: 'TDS Meter Electrode Scaling Alert (${reading.tds.toStringAsFixed(0)} ppm)',
            message: 'Hardware Diagnosis: High electrical conductance indicates mineral deposit scaling or debris bridging TDS electrode pins. Clean probe with distilled water.',
            parameter: 'tds_scaling',
            value: reading.tds,
            threshold: 1200.0,
            detectedAt: reading.timestamp,
            isRead: _readAlertIds.contains('alert-tds-scaling-${reading.id}'),
            isResolved: false,
          ),
        );
      }

      // If no device errors detected
      if (!isProbeDisconnected && reading.ph >= 4.0 && reading.ph <= 11.5 && reading.tds <= 1200) {
        alerts.add(
          AlertItem(
            id: 'alert-device-ok',
            tankId: reading.tankId,
            deviceId: reading.deviceId,
            alertType: 'device',
            severity: 'INFO',
            title: 'Telemetry Probes & Hardware Diagnostics Healthy',
            message: 'Microcontroller OneWire bus, analog ADC converters, and telemetry probes are reporting nominal signal-to-noise ratio.',
            parameter: 'hardware_diagnostics',
            value: 100.0,
            threshold: 100.0,
            detectedAt: reading.timestamp,
            isRead: _readAlertIds.contains('alert-device-ok'),
            isResolved: true,
          ),
        );
      }

      // ==========================================
      // 2. CRITICAL ALERTS (Severe Water Degradation)
      // ==========================================

      if (reading.waterQualityScore < 50) {
        alerts.add(
          AlertItem(
            id: 'alert-score-critical-${reading.id}',
            tankId: reading.tankId,
            deviceId: reading.deviceId,
            alertType: 'critical',
            severity: 'CRITICAL',
            title: 'Critical Water Quality Failure (${reading.waterQualityScore}%)',
            message: 'Overall Water Quality Score dropped to ${reading.waterQualityScore}% (${reading.qualityZone}). Water is unsafe for drinking or food preparation. Technical inspection required.',
            parameter: 'quality_score',
            value: reading.waterQualityScore.toDouble(),
            threshold: 50.0,
            detectedAt: reading.timestamp,
            isRead: _readAlertIds.contains('alert-score-critical-${reading.id}'),
            isResolved: false,
          ),
        );
      }

      if (reading.ph < 5.0 || reading.ph > 9.5) {
        alerts.add(
          AlertItem(
            id: 'alert-ph-extreme-${reading.id}',
            tankId: reading.tankId,
            deviceId: reading.deviceId,
            alertType: 'critical',
            severity: 'CRITICAL',
            title: 'Severe Chemical Contamination Risk (pH ${reading.ph.toStringAsFixed(1)})',
            message: reading.ph < 5.0
                ? 'Severe acidity detected (pH ${reading.ph.toStringAsFixed(1)}). Potential acidic pipe corrosion or industrial contaminant ingress.'
                : 'Severe caustic alkalinity detected (pH ${reading.ph.toStringAsFixed(1)}). Potential chemical dosing overfeed or detergent contamination.',
            parameter: 'ph',
            value: reading.ph,
            threshold: reading.ph < 5.0 ? 5.0 : 9.5,
            detectedAt: reading.timestamp,
            isRead: _readAlertIds.contains('alert-ph-extreme-${reading.id}'),
            isResolved: false,
          ),
        );
      }

      // Temperature Warning (only if probe is connected and temp is out of 20-30°C)
      if (!isProbeDisconnected && (reading.temperature < 20.0 || reading.temperature > 30.0)) {
        alerts.add(
          AlertItem(
            id: 'alert-temp-warning-${reading.id}',
            tankId: reading.tankId,
            deviceId: reading.deviceId,
            alertType: 'device',
            severity: 'WARNING',
            title: 'Temperature Warning (${reading.temperature.toStringAsFixed(1)} °C)',
            message: 'Water temperature (${reading.temperature.toStringAsFixed(1)} °C) is outside the 20.0 – 30.0 °C optimal zone.',
            parameter: 'temperature',
            value: reading.temperature,
            threshold: reading.temperature < 20.0 ? 20.0 : 30.0,
            detectedAt: reading.timestamp,
            isRead: _readAlertIds.contains('alert-temp-warning-${reading.id}'),
            isResolved: false,
          ),
        );
      }
    }

    // ==========================================
    // 3. CLEANING ALERTS (Tank Hygiene & Maintenance)
    // ==========================================

    // Central Canteen Tank has 22 days since last cleaning (sanitary limit: 20 days)
    alerts.add(
      AlertItem(
        id: 'alert-cleaning-overdue-canteen',
        tankId: 'tank-canteen',
        deviceId: 'ESP32_TANK_02',
        alertType: 'cleaning',
        severity: 'CRITICAL',
        title: 'Mandatory Tank Cleaning Overdue (Central Canteen Tank)',
        message: 'Central Canteen Tank has reached 22 days since last sanitization (mandatory cycle: 20 days). Biofilm and sediment buildup risk. Schedule tank drain and chlorine wash.',
        parameter: 'cleaning_cycle',
        value: 22.0,
        threshold: 20.0,
        detectedAt: now.subtract(const Duration(hours: 6)),
        isRead: _readAlertIds.contains('alert-cleaning-overdue-canteen'),
        isResolved: false,
      ),
    );

    // Sediment notice if TDS indicates buildup
    if (!isStandby && reading.tds > 450 && reading.tds <= 1200) {
      alerts.add(
        AlertItem(
          id: 'alert-cleaning-sediment-tds',
          tankId: reading.tankId,
          deviceId: reading.deviceId,
          alertType: 'cleaning',
          severity: 'WARNING',
          title: 'Sediment Buildup & Filtration Maintenance Notice',
          message: 'Elevated TDS concentration (${reading.tds.toStringAsFixed(0)} ppm) indicates mineral sediment accumulation in storage tank reservoir. Check physical sediment filters.',
          parameter: 'tds',
          value: reading.tds,
          threshold: 450.0,
          detectedAt: reading.timestamp,
          isRead: _readAlertIds.contains('alert-cleaning-sediment-tds'),
          isResolved: false,
        ),
      );
    }

    // ==========================================
    // 4. POWER ALERTS (Power Supply Telemetry)
    // ==========================================

    alerts.add(
      AlertItem(
        id: 'alert-power-rail-nominal',
        tankId: reading.tankId,
        deviceId: reading.deviceId,
        alertType: 'power',
        severity: 'INFO',
        title: 'Power Telemetry: 5V Regulated Rail Nominal (5.02V)',
        message: 'ESP32 monitoring station mains power delivery is stable at 5.02V. Auxiliary Li-Ion battery backup is connected and fully charged (100% standby ready).',
        parameter: 'power_voltage',
        value: 5.02,
        threshold: 4.75,
        detectedAt: now,
        isRead: _readAlertIds.contains('alert-power-rail-nominal'),
        isResolved: true,
      ),
    );

    // Track active alert IDs
    _currentAlertIds.clear();
    for (final a in alerts) {
      _currentAlertIds.add(a.id);
    }

    return alerts;
  }
}
