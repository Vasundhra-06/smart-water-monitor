class AlertItem {
  final String id;
  final String tankId;
  final String? deviceId;
  final String alertType; // info, warning, critical, cleaning, device, power
  final String severity; // INFO, WARNING, CRITICAL
  final String title;
  final String message;
  final String? parameter;
  final double? value;
  final double? threshold;
  final DateTime detectedAt;
  final bool isRead;
  final bool isResolved;
  final DateTime? resolvedAt;

  AlertItem({
    required this.id,
    required this.tankId,
    this.deviceId,
    required this.alertType,
    required this.severity,
    required this.title,
    required this.message,
    this.parameter,
    this.value,
    this.threshold,
    required this.detectedAt,
    required this.isRead,
    required this.isResolved,
    this.resolvedAt,
  });

  factory AlertItem.fromJson(Map<String, dynamic> json) {
    return AlertItem(
      id: json['id'] ?? '',
      tankId: json['tank_id'] ?? '',
      deviceId: json['device_id'],
      alertType: json['alert_type'] ?? 'info',
      severity: json['severity'] ?? 'INFO',
      title: json['title'] ?? 'System Alert',
      message: json['message'] ?? '',
      parameter: json['parameter'],
      value: (json['value'] as num?)?.toDouble(),
      threshold: (json['threshold'] as num?)?.toDouble(),
      detectedAt: json['detected_at'] != null
          ? DateTime.parse(json['detected_at'])
          : DateTime.now(),
      isRead: json['is_read'] ?? false,
      isResolved: json['is_resolved'] ?? false,
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'])
          : null,
    );
  }

  AlertItem copyWith({
    String? id,
    String? tankId,
    String? deviceId,
    String? alertType,
    String? severity,
    String? title,
    String? message,
    String? parameter,
    double? value,
    double? threshold,
    DateTime? detectedAt,
    bool? isRead,
    bool? isResolved,
    DateTime? resolvedAt,
  }) {
    return AlertItem(
      id: id ?? this.id,
      tankId: tankId ?? this.tankId,
      deviceId: deviceId ?? this.deviceId,
      alertType: alertType ?? this.alertType,
      severity: severity ?? this.severity,
      title: title ?? this.title,
      message: message ?? this.message,
      parameter: parameter ?? this.parameter,
      value: value ?? this.value,
      threshold: threshold ?? this.threshold,
      detectedAt: detectedAt ?? this.detectedAt,
      isRead: isRead ?? this.isRead,
      isResolved: isResolved ?? this.isResolved,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }
}
