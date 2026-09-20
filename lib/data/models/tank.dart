import '../../core/constants/app_constants.dart';

class Tank {
  final String id;
  final String tankName;
  final String location;
  final double capacity; // Liters
  final String description;
  final TankStatus status;
  final String? deviceId;
  final DateTime installationDate;
  final DateTime lastCleanedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Tank({
    required this.id,
    required this.tankName,
    required this.location,
    required this.capacity,
    required this.description,
    required this.status,
    this.deviceId,
    required this.installationDate,
    required this.lastCleanedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  int get daysSinceCleaning {
    return DateTime.now().difference(lastCleanedAt).inDays;
  }

  factory Tank.fromJson(Map<String, dynamic> json) {
    return Tank(
      id: json['id'] ?? '',
      tankName: json['tank_name'] ?? 'Unnamed Tank',
      location: json['location'] ?? 'Unknown',
      capacity: (json['capacity'] as num?)?.toDouble() ?? 5000.0,
      description: json['description'] ?? '',
      status: _parseTankStatus(json['status']),
      deviceId: json['device_id'],
      installationDate: json['installation_date'] != null
          ? DateTime.parse(json['installation_date'])
          : DateTime.now(),
      lastCleanedAt: json['last_cleaned_at'] != null
          ? DateTime.parse(json['last_cleaned_at'])
          : DateTime.now().subtract(const Duration(days: 10)),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
    );
  }

  static TankStatus _parseTankStatus(dynamic status) {
    if (status == 'offline') return TankStatus.offline;
    if (status == 'maintenance') return TankStatus.maintenance;
    return TankStatus.online;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tank_name': tankName,
      'location': location,
      'capacity': capacity,
      'description': description,
      'status': status.name,
      'device_id': deviceId,
      'installation_date': installationDate.toIso8601String(),
      'last_cleaned_at': lastCleanedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
