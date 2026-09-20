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
    final temperature = json.containsKey('field3') ? parseVal(json['field3'], 26.5) : parseVal(json['temperature'], 26.5);
    final turbidity = parseVal(json['turbidity'], 1.2);

    DateTime ts;
    if (json['created_at'] != null) {
      ts = DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now();
    } else if (json['timestamp'] != null) {
      ts = DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now();
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
    );
  }

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
    };
  }

  WaterQualityScoreResult get scoreAnalysis {
    return WaterQualityScoringService.instance.calculateWaterQualityScore(this);
  }

  int get waterQualityScore {
    return scoreAnalysis.score;
  }

  String get qualityZone {
    return scoreAnalysis.status;
  }
}
