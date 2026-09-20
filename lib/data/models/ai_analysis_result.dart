class AnomalyItem {
  final String parameter;
  final String severity;
  final String reason;

  AnomalyItem({
    required this.parameter,
    required this.severity,
    required this.reason,
  });

  factory AnomalyItem.fromJson(Map<String, dynamic> json) {
    return AnomalyItem(
      parameter: json['parameter'] ?? '',
      severity: json['severity'] ?? 'LOW',
      reason: json['reason'] ?? '',
    );
  }
}

class AIAnalysisResult {
  final String id;
  final String tankId;
  final DateTime analysisTime;
  final int waterQualityScore;
  final String status; // EXCELLENT, GOOD, ATTENTION, POOR, CRITICAL
  final String summary;
  final List<AnomalyItem> detectedAnomalies;
  final String trend; // STABLE, IMPROVING, DETERIORATING
  final bool cleaningRecommendation;
  final String predictedDeterioration;
  final double confidence;

  AIAnalysisResult({
    required this.id,
    required this.tankId,
    required this.analysisTime,
    required this.waterQualityScore,
    required this.status,
    required this.summary,
    required this.detectedAnomalies,
    required this.trend,
    required this.cleaningRecommendation,
    required this.predictedDeterioration,
    required this.confidence,
  });

  factory AIAnalysisResult.fromJson(Map<String, dynamic> json) {
    var rawAnomalies = json['detected_anomalies'];
    List<AnomalyItem> anomalyList = [];
    if (rawAnomalies is List) {
      anomalyList = rawAnomalies
          .map((a) => AnomalyItem.fromJson(a as Map<String, dynamic>))
          .toList();
    }

    return AIAnalysisResult(
      id: json['id'] ?? '',
      tankId: json['tank_id'] ?? '',
      analysisTime: json['analysis_time'] != null
          ? DateTime.parse(json['analysis_time'])
          : DateTime.now(),
      waterQualityScore: json['water_quality_score'] ?? json['score'] ?? 85,
      status: json['status'] ?? 'GOOD',
      summary: json['summary'] ?? 'Water parameters stable.',
      detectedAnomalies: anomalyList,
      trend: json['trend'] ?? 'STABLE',
      cleaningRecommendation: json['cleaning_recommendation'] ?? json['cleaning_recommended'] ?? false,
      predictedDeterioration: json['predicted_deterioration'] ?? 'Baseline stability normal.',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.95,
    );
  }
}
