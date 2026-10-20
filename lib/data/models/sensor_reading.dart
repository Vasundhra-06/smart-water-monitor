import '../../core/services/water_quality_scoring_service.dart';

class SensorReading {
  final String id;
  final String deviceId;
  final String tankId;
  final DateTime timestamp;
  final double ph;
  final double tds;
  final double turbidity;
  final double temperature;
  final double waterLevel;
  final double? directQualityScore;
  final double? rawTemperature;
  final bool isProbeDisconnected;

  SensorReading({
    required this.id,
    required this.deviceId,
    required this.tankId,
    required this.timestamp,
    required this.ph,
    required this.tds,
    required this.turbidity,
    required this.temperature,
    required this.waterLevel,
    this.directQualityScore,
    this.rawTemperature,
    this.isProbeDisconnected = false,
  });

  factory SensorReading.fromJson(Map<String, dynamic> json) {
    return SensorReading(
      id: json['id']?.toString() ?? '',
      deviceId: json['device_id'] ?? '',
      tankId: json['tank_id'] ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      ph: (json['ph'] as num).toDouble(),
      tds: (json['tds'] as num).toDouble(),
      turbidity: (json['turbidity'] != null ? (json['turbidity'] as num).toDouble() : 1.2),
      temperature: (json['temperature'] as num).toDouble(),
      waterLevel: (json['water_level'] != null ? (json['water_level'] as num).toDouble() : 78.0),
      directQualityScore: json['quality'] != null ? (json['quality'] as num).toDouble() : null,
    );
  }

  factory SensorReading.fromThingSpeakBackendJson(Map<String, dynamic> json, {String tankId = 'tank-main'}) {
    double parseVal(dynamic v, double fallback) {
      if (v == null) return fallback;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? fallback;
    }

    final tds = json.containsKey('field1') ? parseVal(json['field1'], 235.0) : parseVal(json['tds'], 235.0);
    final ph = json.containsKey('field2') ? parseVal(json['field2'], 7.2) : parseVal(json['ph'], 7.2);
    final rawTemp = json.containsKey('field3') ? parseVal(json['field3'], 26.5) : parseVal(json['temperature'], 26.5);
    final probeDisconnected = rawTemp <= -50.0 || rawTemp == -127.0;
    // DS18B20 digital temperature sensors return -127.0 when wire is disconnected or floating
    final temperature = (rawTemp < 0 || rawTemp > 65) ? 27.5 : rawTemp;
    final turbidity = parseVal(json['turbidity'], 1.2);
    final rawQuality = json.containsKey('field4') && json['field4'] != null
        ? parseVal(json['field4'], -1.0)
        : (json.containsKey('quality') ? parseVal(json['quality'], -1.0) : -1.0);

    DateTime ts;
    if (json['created_at'] != null) {
      ts = (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()).toLocal();
    } else if (json['timestamp'] != null) {
      ts = (DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()).toLocal();
    } else {
      ts = DateTime.now();
    }

    return SensorReading(
      id: json['entry_id']?.toString() ?? '1',
      deviceId: 'ESP32_THINGSPEAK',
      tankId: tankId,
      timestamp: ts,
      ph: ph,
      tds: tds,
      turbidity: turbidity,
      temperature: temperature,
      waterLevel: parseVal(json['water_level'], 78.0),
      directQualityScore: rawQuality >= 0 ? rawQuality : null,
      rawTemperature: rawTemp,
      isProbeDisconnected: probeDisconnected,
    );
  }

  factory SensorReading.zero({String tankId = 'tank-main'}) {
    return SensorReading(
      id: '0',
      deviceId: 'ESP32_STANDBY',
      tankId: tankId,
      timestamp: DateTime.now(),
      ph: 0.0,
      tds: 0.0,
      turbidity: 0.0,
      temperature: 0.0,
      waterLevel: 0.0,
      directQualityScore: 0.0,
      rawTemperature: 0.0,
      isProbeDisconnected: false,
    );
  }

  bool get isZero => ph == 0.0 && tds == 0.0 && temperature == 0.0;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'device_id': deviceId,
      'tank_id': tankId,
      'timestamp': timestamp.toIso8601String(),
      'ph': ph,
      'tds': tds,
      'turbidity': turbidity,
      'temperature': temperature,
      'water_level': waterLevel,
      'quality': directQualityScore,
    };
  }

  WaterQualityScoreResult get scoreAnalysis {
    if (isZero) {
      return WaterQualityScoreResult(
        score: 0,
        status: 'Standby',
        parameterImpacts: {},
        sortedDeterioratingParameters: [],
        primaryContributorName: 'None',
        aiSummary: 'Sensors reset to zero. Dip sensor into water to begin streaming live analysis.',
        inspectionRecommended: false,
      );
    }
    return WaterQualityScoringService.instance.calculateWaterQualityScore(this);
  }

  int get waterQualityScore {
    if (isZero) return 0;
    if (directQualityScore != null && directQualityScore! >= 0) {
      return directQualityScore!.round().clamp(0, 100);
    }
    return scoreAnalysis.score;
  }

  // Temperature-compensated TDS normalized to 25°C (TDS25)
  // Firmware applies: compVoltage = voltage / [1.0 + 0.02 * (temp - 25.0)]
  double get compensatedTds => tds;

  // Raw TDS estimate at current water temperature (uncompensated)
  // TDST = TDS25 * [1.0 + 0.02 * (T - 25)]
  double get rawTds {
    if (isZero) return 0.0;
    return tds * (1.0 + 0.020 * (temperature - 25.0));
  }

  // Electrical Conductivity Estimate (standard conversion factor 0.5)
  // ECT = Raw TDS / 0.5 (µS/cm)
  double get rawConductivityEstimate => rawTds / 0.5;

  // Electrical Conductivity Normalized to 25°C
  // EC25 = Compensated TDS / 0.5 (µS/cm)
  double get compensatedConductivity25 => compensatedTds / 0.5;

  // BIS IS 10500 pH Classification
  String get bisPhStatus {
    if (isZero) return 'Standby';
    if (ph < 6.5) return 'Below pH Acceptable Range (<6.5)';
    if (ph <= 8.5) return 'Within pH Acceptable Range (6.5 – 8.5)';
    return 'Above pH Acceptable Range (>8.5)';
  }

  // BIS IS 10500 & Project Target TDS Classification
  String get bisTdsStatus {
    if (isZero) return 'Standby';
    if (tds <= 300.0) return 'Project TDS Target Met (≤300 mg/L)';
    if (tds <= 500.0) return 'Above Project Target — Within BIS Acceptable TDS Limit (≤500 mg/L)';
    if (tds <= 2000.0) return 'Above BIS Acceptable TDS Limit (501 – 2000 mg/L)';
    return 'Above BIS Permissible TDS Limit (>2000 mg/L)';
  }

  // Overall Scientific Drinking-Water Status
  // (Recognizing pH/TDS cannot independently determine microbial safety)
  String get overallScientificStatus {
    if (isZero) return 'Standby Mode — Probes Unsubmerged';
    if (isProbeDisconnected) return 'Invalid Sensor Reading — Probe Disconnected';
    if (waterQualityScore >= 70 && ph >= 6.5 && ph <= 8.5 && tds <= 500.0) {
      return 'Within Monitored Limits — laboratory verification required';
    }
    if (waterQualityScore >= 40) {
      return 'Water Quality Warning — Parameter Deviation';
    }
    return 'Water Quality Alert — Immediate Inspection Required';
  }

  String get qualityZone {
    if (isZero) return 'Standby';
    if (directQualityScore != null && directQualityScore! >= 0) {
      final q = directQualityScore!;
      if (q >= 70) return 'Monitored Limits Met';
      if (q >= 40) return 'Warning';
      return 'Danger';
    }
    return scoreAnalysis.status;
  }
}
