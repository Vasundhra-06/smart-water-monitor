class CleaningRecord {
  final String id;
  final String tankId;
  final DateTime cleanedAt;
  final String cleanedBy;
  final String notes;
  final String cleaningMethod;
  final DateTime createdAt;

  CleaningRecord({
    required this.id,
    required this.tankId,
    required this.cleanedAt,
    required this.cleanedBy,
    required this.notes,
    required this.cleaningMethod,
    required this.createdAt,
  });

  factory CleaningRecord.fromJson(Map<String, dynamic> json) {
    return CleaningRecord(
      id: json['id'] ?? '',
      tankId: json['tank_id'] ?? '',
      cleanedAt: json['cleaned_at'] != null
          ? DateTime.parse(json['cleaned_at'])
          : DateTime.now(),
      cleanedBy: json['cleaned_by'] ?? 'Technician',
      notes: json['notes'] ?? '',
      cleaningMethod: json['cleaning_method'] ?? 'High-pressure Jet Wash',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }
}
