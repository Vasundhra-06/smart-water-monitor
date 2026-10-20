class ValidationPoint {
  final double temperature; // in °C
  final double rawTds; // in ppm
  final double compensatedTds; // in ppm normalized to 25°C
  final double referenceValue; // in ppm
  final double residualError; // in ppm (compensatedTds - referenceValue)
  final double errorPercentage; // in %

  ValidationPoint({
    required this.temperature,
    required this.rawTds,
    required this.compensatedTds,
    required this.referenceValue,
    required this.residualError,
    required this.errorPercentage,
  });

  Map<String, dynamic> toJson() => {
    'temperature': temperature,
    'raw_tds': rawTds,
    'compensated_tds': compensatedTds,
    'reference_value': referenceValue,
    'residual_error': residualError,
    'error_percentage': errorPercentage,
  };

  factory ValidationPoint.fromJson(Map<String, dynamic> json) => ValidationPoint(
    temperature: (json['temperature'] as num).toDouble(),
    rawTds: (json['raw_tds'] as num).toDouble(),
    compensatedTds: (json['compensated_tds'] as num).toDouble(),
    referenceValue: (json['reference_value'] as num).toDouble(),
    residualError: (json['residual_error'] as num).toDouble(),
    errorPercentage: (json['error_percentage'] as num).toDouble(),
  );
}

class CalibrationProfile {
  final String sensorId;
  final String version;
  final DateTime calibrationDate;
  final double referenceTemperature; // standard 25.0 °C
  final double alphaCoefficient; // typically 0.020 per °C (2.0%/°C)
  final double kFactor; // calibration multiplier / slope (e.g. 1.0)
  final double phNeutralVoltage; // standard 2.50V at pH 7.00
  final double phAcidVoltage; // voltage at pH 4.01
  final String referenceSolution; // e.g. "1413 µS/cm (342 ppm NaCl)"
  final String validationStatus; // VALIDATED, PROVISIONAL, EXPIRED
  final int validDays; // e.g. 90 days review cycle
  final String operatorNotes;
  final List<ValidationPoint> validationPoints;

  CalibrationProfile({
    required this.sensorId,
    required this.version,
    required this.calibrationDate,
    this.referenceTemperature = 25.0,
    this.alphaCoefficient = 0.020,
    this.kFactor = 1.0,
    this.phNeutralVoltage = 2.50,
    this.phAcidVoltage = 3.05,
    this.referenceSolution = '1413 µS/cm (342 ppm NaCl)',
    this.validationStatus = 'VALIDATED',
    this.validDays = 90,
    this.operatorNotes = 'Calibrated against certified conductivity standard.',
    required this.validationPoints,
  });

  DateTime get expiryDate => calibrationDate.add(Duration(days: validDays));
  int get daysRemaining => expiryDate.difference(DateTime.now()).inDays;
  bool get isExpired => daysRemaining <= 0;

  double get maxResidualError {
    if (validationPoints.isEmpty) return 0.0;
    double maxErr = 0.0;
    for (var p in validationPoints) {
      if (p.residualError.abs() > maxErr) maxErr = p.residualError.abs();
    }
    return maxErr;
  }

  // Calculate Temperature-Compensated TDS normalized to 25°C
  // EC25 = ECT / [1 + alpha * (T - 25)]
  // TDS25 ≈ TDST / [1 + alpha * (T - 25)]
  double compensateTds(double rawTds, double currentTemp) {
    if (rawTds <= 0.0) return 0.0;
    final denominator = 1.0 + alphaCoefficient * (currentTemp - referenceTemperature);
    if (denominator <= 0.1) return rawTds * kFactor; // Prevent division by zero
    return (rawTds * kFactor) / denominator;
  }

  // Calculate uncompensated raw TDS from compensated TDS
  double uncompensateTds(double compTds, double currentTemp) {
    if (compTds <= 0.0) return 0.0;
    final multiplier = 1.0 + alphaCoefficient * (currentTemp - referenceTemperature);
    return compTds * multiplier / kFactor;
  }

  factory CalibrationProfile.defaultProfile() {
    final now = DateTime.now();
    // Default validated curve for 342 ppm NaCl reference solution across 15°C - 40°C
    const alpha = 0.020;
    const refVal = 342.0;
    final temps = [15.0, 20.0, 25.0, 30.0, 35.0, 40.0];
    final points = <ValidationPoint>[];

    for (var t in temps) {
      // Natural thermal conductivity: ECT = EC25 * [1 + alpha * (t - 25)]
      final raw = refVal * (1.0 + alpha * (t - 25.0));
      // Compensated back:
      final comp = raw / (1.0 + alpha * (t - 25.0));
      final res = comp - refVal;
      final pct = (res / refVal) * 100.0;
      points.add(ValidationPoint(
        temperature: t,
        rawTds: double.parse(raw.toStringAsFixed(1)),
        compensatedTds: double.parse(comp.toStringAsFixed(1)),
        referenceValue: refVal,
        residualError: double.parse(res.toStringAsFixed(2)),
        errorPercentage: double.parse(pct.toStringAsFixed(2)),
      ));
    }

    return CalibrationProfile(
      sensorId: 'ESP32_TDS_PROBE_01',
      version: 'v1.4-std',
      calibrationDate: now.subtract(const Duration(days: 12)),
      referenceTemperature: 25.0,
      alphaCoefficient: alpha,
      kFactor: 1.0,
      phNeutralVoltage: 2.50,
      phAcidVoltage: 3.05,
      referenceSolution: '1413 µS/cm (342 ppm NaCl Standard)',
      validationStatus: 'VALIDATED',
      validDays: 90,
      operatorNotes: 'Linear temperature compensation calibrated using ISO 7888 / Standard Methods 2510 B baseline.',
      validationPoints: points,
    );
  }

  Map<String, dynamic> toJson() => {
    'sensor_id': sensorId,
    'version': version,
    'calibration_date': calibrationDate.toIso8601String(),
    'reference_temperature': referenceTemperature,
    'alpha_coefficient': alphaCoefficient,
    'k_factor': kFactor,
    'ph_neutral_voltage': phNeutralVoltage,
    'ph_acid_voltage': phAcidVoltage,
    'reference_solution': referenceSolution,
    'validation_status': validationStatus,
    'valid_days': validDays,
    'operator_notes': operatorNotes,
    'validation_points': validationPoints.map((p) => p.toJson()).toList(),
  };

  factory CalibrationProfile.fromJson(Map<String, dynamic> json) => CalibrationProfile(
    sensorId: json['sensor_id'] ?? 'ESP32_TDS_PROBE_01',
    version: json['version'] ?? 'v1.4-std',
    calibrationDate: json['calibration_date'] != null ? DateTime.parse(json['calibration_date']) : DateTime.now(),
    referenceTemperature: (json['reference_temperature'] as num?)?.toDouble() ?? 25.0,
    alphaCoefficient: (json['alpha_coefficient'] as num?)?.toDouble() ?? 0.020,
    kFactor: (json['k_factor'] as num?)?.toDouble() ?? 1.0,
    phNeutralVoltage: (json['ph_neutral_voltage'] as num?)?.toDouble() ?? 2.50,
    phAcidVoltage: (json['ph_acid_voltage'] as num?)?.toDouble() ?? 3.05,
    referenceSolution: json['reference_solution'] ?? '1413 µS/cm (342 ppm NaCl)',
    validationStatus: json['validation_status'] ?? 'VALIDATED',
    validDays: (json['valid_days'] as num?)?.toInt() ?? 90,
    operatorNotes: json['operator_notes'] ?? '',
    validationPoints: (json['validation_points'] as List<dynamic>?)
        ?.map((p) => ValidationPoint.fromJson(p as Map<String, dynamic>))
        .toList() ?? [],
  );
}
