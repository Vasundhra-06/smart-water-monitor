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
    return SensorReading(
      id: json['entry_id']?.toString() ?? '1',
      deviceId: 'ESP32_THINGSPEAK',
      tankId: tankId,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      ph: (json['ph'] as num).toDouble(),
      tds: (json['tds'] as num).toDouble(),
      turbidity: (json['turbidity'] != null ? (json['turbidity'] as num).toDouble() : 1.2),
      temperature: (json['temperature'] as num).toDouble(),
      waterLevel: 78.0,
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
