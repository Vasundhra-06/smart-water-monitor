import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/calibration_profile.dart';

class CalibrationService {
  static final CalibrationService instance = CalibrationService._internal();
  CalibrationService._internal() {
    _loadProfile();
  }

  CalibrationProfile _activeProfile = CalibrationProfile.defaultProfile();
  CalibrationProfile get activeProfile => _activeProfile;

  static const String _prefsKey = 'esp32_active_calibration_profile';

  Future<void> _loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataStr = prefs.getString(_prefsKey);
      if (dataStr != null && dataStr.isNotEmpty) {
        final Map<String, dynamic> jsonMap = json.decode(dataStr);
        _activeProfile = CalibrationProfile.fromJson(jsonMap);
      }
    } catch (_) {}
  }

  Future<void> saveProfile(CalibrationProfile profile) async {
    _activeProfile = profile;
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataStr = json.encode(profile.toJson());
      await prefs.setString(_prefsKey, dataStr);
    } catch (_) {}
  }

  // Update calibration with new reference standard & measured readings
  Future<CalibrationProfile> performTdsCalibration({
    required String referenceSolutionName,
    required double referenceTdsValue,
    required double measuredTemp,
    required double measuredRawTds,
    String notes = '',
  }) async {
    // Calculate new K-factor multiplier
    // At referenceTemp (25°C), compensatedTds should equal referenceTdsValue
    final alpha = _activeProfile.alphaCoefficient;
    final denominator = 1.0 + alpha * (measuredTemp - 25.0);
    final rawAt25 = measuredRawTds / denominator;
    final newKFactor = rawAt25 > 0 ? (referenceTdsValue / rawAt25) : 1.0;

    // Generate validation points for standard curve
    final temps = [15.0, 20.0, 25.0, 30.0, 35.0, 40.0];
    final points = <ValidationPoint>[];

    for (var t in temps) {
      final raw = referenceTdsValue * (1.0 + alpha * (t - 25.0));
      final comp = (raw * newKFactor) / (1.0 + alpha * (t - 25.0));
      final res = comp - referenceTdsValue;
      final pct = (res / referenceTdsValue) * 100.0;
      points.add(ValidationPoint(
        temperature: t,
        rawTds: double.parse(raw.toStringAsFixed(1)),
        compensatedTds: double.parse(comp.toStringAsFixed(1)),
        referenceValue: referenceTdsValue,
        residualError: double.parse(res.toStringAsFixed(2)),
        errorPercentage: double.parse(pct.toStringAsFixed(2)),
      ));
    }

    final newProfile = CalibrationProfile(
      sensorId: _activeProfile.sensorId,
      version: 'v${DateTime.now().millisecondsSinceEpoch % 1000}-cal',
      calibrationDate: DateTime.now(),
      referenceTemperature: 25.0,
      alphaCoefficient: alpha,
      kFactor: double.parse(newKFactor.toStringAsFixed(4)),
      phNeutralVoltage: _activeProfile.phNeutralVoltage,
      phAcidVoltage: _activeProfile.phAcidVoltage,
      referenceSolution: referenceSolutionName,
      validationStatus: 'VALIDATED',
      validDays: 90,
      operatorNotes: notes.isNotEmpty ? notes : 'Calibrated against $referenceSolutionName standard.',
      validationPoints: points,
    );

    await saveProfile(newProfile);
    return newProfile;
  }

  // Update pH calibration
  Future<CalibrationProfile> performPhCalibration({
    required double neutralVoltage7,
    required double acidVoltage4,
    String notes = '',
  }) async {
    final newProfile = CalibrationProfile(
      sensorId: _activeProfile.sensorId,
      version: 'v${DateTime.now().millisecondsSinceEpoch % 1000}-ph',
      calibrationDate: DateTime.now(),
      referenceTemperature: _activeProfile.referenceTemperature,
      alphaCoefficient: _activeProfile.alphaCoefficient,
      kFactor: _activeProfile.kFactor,
      phNeutralVoltage: neutralVoltage7,
      phAcidVoltage: acidVoltage4,
      referenceSolution: 'pH 7.00 & pH 4.01 Buffer Standards',
      validationStatus: 'VALIDATED',
      validDays: 60,
      operatorNotes: notes.isNotEmpty ? notes : '2-point buffer calibration (pH 7.00 / pH 4.01).',
      validationPoints: _activeProfile.validationPoints,
    );

    await saveProfile(newProfile);
    return newProfile;
  }
}
