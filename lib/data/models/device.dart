import '../../core/constants/app_constants.dart';

class Device {
  final String id;
  final String deviceId;
  final String? tankId;
  final String deviceName;
  final String firmwareVersion;
  final bool isOnline;
  final DateTime lastSeenAt;
  final PowerStatus powerStatus;
  final double batteryVoltage;

  Device({
    required this.id,
    required this.deviceId,
    this.tankId,
    required this.deviceName,
    required this.firmwareVersion,
    required this.isOnline,
    required this.lastSeenAt,
    required this.powerStatus,
    required this.batteryVoltage,
  });

  int get batteryPercentage {
    // 3.3V = 0%, 4.2V = 100%
    if (batteryVoltage >= 4.2) return 100;
    if (batteryVoltage <= 3.3) return 0;
    return (((batteryVoltage - 3.3) / (4.2 - 3.3)) * 100).round();
  }

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] ?? '',
      deviceId: json['device_id'] ?? '',
      tankId: json['tank_id'],
      deviceName: json['device_name'] ?? 'ESP32 Device',
      firmwareVersion: json['firmware_version'] ?? '1.0.0',
      isOnline: (json['connection_status'] ?? 'online') == 'online',
      lastSeenAt: json['last_seen_at'] != null
          ? DateTime.parse(json['last_seen_at'])
          : DateTime.now(),
      powerStatus: _parsePowerStatus(json['power_source']),
      batteryVoltage: (json['battery_voltage'] as num?)?.toDouble() ?? 4.2,
    );
  }

  static PowerStatus _parsePowerStatus(dynamic p) {
    if (p == 'battery') return PowerStatus.backup;
    if (p == 'offline') return PowerStatus.offline;
    return PowerStatus.mains;
  }
}
