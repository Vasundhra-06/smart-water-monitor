import '../constants/app_constants.dart';
import '../../data/models/sensor_reading.dart';

class ParameterImpact {
  final String name;
  final double rawValue;
  final String unit;
  final int impactPoints; // Negative points, e.g. -22
  final String status; // HIGH IMPACT, MODERATE IMPACT, LOW IMPACT, NORMAL
  final String trend; // ↑ Increasing, ↓ Decreasing, → Stable
  final String expectedRange;
  final double historical7DayAvg;
  final double percentageChange;
  final String reason;

  ParameterImpact({
    required this.name,
    required this.rawValue,
    required this.unit,
    required this.impactPoints,
    required this.status,
    required this.trend,
    required this.expectedRange,
    required this.historical7DayAvg,
    required this.percentageChange,
    required this.reason,
  });
}

class WaterQualityScoreResult {
  final int score; // 0 - 100
  final String status; // SAFE (70-100), WARNING (40-69), DANGER (0-39)
  final Map<String, ParameterImpact> parameterImpacts;
  final List<ParameterImpact> sortedDeterioratingParameters;
  final String primaryContributorName;
  final String aiSummary;
  final bool inspectionRecommended;

  WaterQualityScoreResult({
    required this.score,
    required this.status,
    required this.parameterImpacts,
    required this.sortedDeterioratingParameters,
    required this.primaryContributorName,
    required this.aiSummary,
    required this.inspectionRecommended,
  });
}

class WaterQualityScoringService {
  static final WaterQualityScoringService instance = WaterQualityScoringService._internal();
  WaterQualityScoringService._internal();

  WaterQualityScoreResult calculateWaterQualityScore(
    SensorReading reading, {
    List<SensorReading>? historical7DayReadings,
  }) {
    // Calculate 7-day historical baselines
    double avgPh = AppConstants.basePh;
    double avgTds = AppConstants.baseTds;
    double avgTurb = AppConstants.baseTurbidity;
    double avgTemp = AppConstants.baseTemperature;

    if (historical7DayReadings != null && historical7DayReadings.isNotEmpty) {
      double sumPh = 0, sumTds = 0, sumTurb = 0, sumTemp = 0;
      for (var r in historical7DayReadings) {
        sumPh += r.ph;
        sumTds += r.tds;
        sumTurb += r.turbidity;
        sumTemp += r.temperature;
      }
      int count = historical7DayReadings.length;
      avgPh = sumPh / count;
      avgTds = sumTds / count;
      avgTurb = sumTurb / count;
      avgTemp = sumTemp / count;
    }

    // 1. Turbidity Impact (Max deduction: 35 pts)
    int turbDeduction = 0;
    String turbStatus = 'NORMAL';
    String turbTrend = '→ Stable';
    String turbReason = 'Turbidity is optimal and clear within acceptable drinking limits.';
    double turbPctChange = ((reading.turbidity - avgTurb) / avgTurb * 100).clamp(-100.0, 500.0);

    if (reading.turbidity > 1.5) {
      turbDeduction = ((reading.turbidity - 1.5) * 15.0).clamp(1.0, 35.0).round();
      turbTrend = reading.turbidity > avgTurb ? '↑ Increasing' : '→ Elevated';
      if (turbDeduction >= 15) {
        turbStatus = 'HIGH IMPACT';
        turbReason = 'Turbidity has increased rapidly compared with the tank\'s 7-day baseline (+${turbPctChange.toStringAsFixed(0)}% deviation).';
      } else if (turbDeduction >= 8) {
        turbStatus = 'MODERATE IMPACT';
        turbReason = 'Turbidity is higher than normal, indicating particulate or sediment accumulation.';
      } else {
        turbStatus = 'LOW IMPACT';
        turbReason = 'Turbidity shows slight elevation from the preferred baseline.';
      }
    }

    // 2. TDS Impact (Max deduction: 30 pts)
    int tdsDeduction = 0;
    String tdsStatus = 'NORMAL';
    String tdsTrend = '→ Stable';
    String tdsReason = 'Dissolved solids level is within optimal bounds for drinking water.';
    double tdsPctChange = ((reading.tds - avgTds) / avgTds * 100).clamp(-100.0, 500.0);

    if (reading.tds > 300) {
      tdsDeduction = ((reading.tds - 300) * 0.15).clamp(1.0, 30.0).round();
      tdsTrend = reading.tds > avgTds ? '↑ Increasing' : '→ Elevated';
      if (tdsDeduction >= 15) {
        tdsStatus = 'HIGH IMPACT';
        tdsReason = 'TDS has risen sharply above acceptable baseline levels (+${tdsPctChange.toStringAsFixed(0)}% change).';
      } else if (tdsDeduction >= 8) {
        tdsStatus = 'MODERATE IMPACT';
        tdsReason = 'TDS is higher than the normal range observed for this tank.';
      } else {
        tdsStatus = 'LOW IMPACT';
        tdsReason = 'TDS is slightly elevated above the ideal threshold.';
      }
    }

    // 3. pH Impact (Max deduction: 20 pts)
    int phDeduction = 0;
    String phStatus = 'NORMAL';
    String phTrend = '→ Stable';
    String phReason = 'pH level is balanced within safe drinking standards.';
    double phPctChange = ((reading.ph - avgPh) / avgPh * 100).clamp(-100.0, 100.0);

    if (reading.ph < 6.5) {
      phDeduction = ((6.5 - reading.ph) * 20.0).clamp(1.0, 20.0).round();
      phTrend = '↓ Decreasing (Acidic)';
      phStatus = phDeduction >= 10 ? 'HIGH IMPACT' : 'MODERATE IMPACT';
      phReason = 'pH has dropped below safe limits toward acidity.';
    } else if (reading.ph > 8.5) {
      phDeduction = ((reading.ph - 8.5) * 20.0).clamp(1.0, 20.0).round();
      phTrend = '↑ Increasing (Alkaline)';
      phStatus = phDeduction >= 10 ? 'HIGH IMPACT' : 'MODERATE IMPACT';
      phReason = 'pH has slightly deviated above the preferred alkaline boundary.';
    } else if ((reading.ph - avgPh).abs() > 0.4) {
      phDeduction = 4;
      phStatus = 'LOW IMPACT';
      phTrend = reading.ph > avgPh ? '↑ Shifting' : '↓ Shifting';
      phReason = 'pH has slightly deviated from the preferred historical average.';
    }

    // 4. Temperature Impact (Max deduction: 10 pts)
    int tempDeduction = 0;
    String tempStatus = 'NORMAL';
    String tempTrend = '→ Normal';
    String tempReason = 'Temperature is optimal for storage.';
    double tempPctChange = ((reading.temperature - avgTemp) / avgTemp * 100).clamp(-100.0, 100.0);

    if (reading.temperature > 28.0) {
      tempDeduction = ((reading.temperature - 28.0) * 3.0).clamp(1.0, 10.0).round();
      tempTrend = '↑ Warm';
      tempStatus = tempDeduction >= 6 ? 'MODERATE IMPACT' : 'LOW IMPACT';
      tempReason = 'Water temperature is elevated, increasing microbial growth risk.';
    }

    // 5. Water Level Impact (Max deduction: 5 pts)
    int levelDeduction = 0;
    String levelStatus = 'NORMAL';
    String levelTrend = '→ Normal';
    String levelReason = 'Storage volume is sufficient.';

    if (reading.waterLevel < 25.0) {
      levelDeduction = ((25.0 - reading.waterLevel) * 0.4).clamp(1.0, 5.0).round();
      levelTrend = '↓ Low Storage';
      levelStatus = 'LOW IMPACT';
      levelReason = 'Tank water level is low.';
    }

    // Calculate Overall Score
    int totalDeductions = turbDeduction + tdsDeduction + phDeduction + tempDeduction + levelDeduction;
    int finalScore = (100 - totalDeductions).clamp(0, 100);

    // Determine Zone (SAFE: 70-100, WARNING: 40-69, DANGER: 0-39)
    String zone = 'SAFE';
    if (finalScore < 40) {
      zone = 'DANGER';
    } else if (finalScore < 70) {
      zone = 'WARNING';
    }

    // Map Parameter Impacts
    final impactMap = {
      'Turbidity': ParameterImpact(
        name: 'Turbidity',
        rawValue: reading.turbidity,
        unit: 'NTU',
        impactPoints: -turbDeduction,
        status: turbStatus,
        trend: turbTrend,
        expectedRange: '0.0 – 1.5 NTU',
        historical7DayAvg: double.parse(avgTurb.toStringAsFixed(2)),
        percentageChange: double.parse(turbPctChange.toStringAsFixed(1)),
        reason: turbReason,
      ),
      'TDS': ParameterImpact(
        name: 'TDS',
        rawValue: reading.tds,
        unit: 'ppm',
        impactPoints: -tdsDeduction,
        status: tdsStatus,
        trend: tdsTrend,
        expectedRange: '100 – 300 ppm',
        historical7DayAvg: double.parse(avgTds.toStringAsFixed(0)),
        percentageChange: double.parse(tdsPctChange.toStringAsFixed(1)),
        reason: tdsReason,
      ),
      'pH': ParameterImpact(
        name: 'pH',
        rawValue: reading.ph,
        unit: '',
        impactPoints: -phDeduction,
        status: phStatus,
        trend: phTrend,
        expectedRange: '6.5 – 8.5',
        historical7DayAvg: double.parse(avgPh.toStringAsFixed(2)),
        percentageChange: double.parse(phPctChange.toStringAsFixed(1)),
        reason: phReason,
      ),
      'Temperature': ParameterImpact(
        name: 'Temperature',
        rawValue: reading.temperature,
        unit: '°C',
        impactPoints: -tempDeduction,
        status: tempStatus,
        trend: tempTrend,
        expectedRange: '20.0 – 28.0 °C',
        historical7DayAvg: double.parse(avgTemp.toStringAsFixed(1)),
        percentageChange: double.parse(tempPctChange.toStringAsFixed(1)),
        reason: tempReason,
      ),
      'Water Level': ParameterImpact(
        name: 'Water Level',
        rawValue: reading.waterLevel,
        unit: '%',
        impactPoints: -levelDeduction,
        status: levelStatus,
        trend: levelTrend,
        expectedRange: '30 – 100 %',
        historical7DayAvg: 80.0,
        percentageChange: 0.0,
        reason: levelReason,
      ),
    };

    // Sort deteriorating parameters by severity of deduction
    List<ParameterImpact> deteriorating = impactMap.values
        .where((p) => p.impactPoints < 0)
        .toList()
      ..sort((a, b) => a.impactPoints.compareTo(b.impactPoints)); // Most negative first

    String primaryContributor = deteriorating.isNotEmpty ? deteriorating.first.name : 'None';

    // Build Human-Understandable AI Explanation (No complex jargon)
    String aiText = '';
    bool inspectRec = false;

    if (zone == 'SAFE') {
      aiText = 'All monitored parameters are currently within configured monitoring ranges and the overall trend is stable.';
      inspectRec = false;
    } else if (zone == 'WARNING') {
      inspectRec = false;
      if (deteriorating.length == 1) {
        aiText = 'Water quality is showing mild deterioration primarily because ${deteriorating.first.name.toLowerCase()} increased compared with the tank\'s normal pattern. Inspection is recommended if the trend continues.';
      } else {
        String names = deteriorating.map((d) => d.name).join(' and ');
        aiText = 'Water quality is showing deterioration. Monitored parameters ($names) are deviating from the tank\'s historical baseline.';
      }
    } else {
      // DANGER
      inspectRec = true;
      if (deteriorating.isNotEmpty) {
        String primary = deteriorating.first.name;
        String others = deteriorating.skip(1).map((d) => d.name).join(', ');
        aiText = 'The overall water-quality score has entered the danger zone ($finalScore / 100). The largest deterioration is associated with $primary${others.isNotEmpty ? ", followed by $others" : ""}. Tank inspection and cleaning are strongly recommended.';
      } else {
        aiText = 'The overall water-quality score has entered the danger zone. Inspect and clean the water tank immediately.';
      }
    }

    return WaterQualityScoreResult(
      score: finalScore,
      status: zone,
      parameterImpacts: impactMap,
      sortedDeterioratingParameters: deteriorating,
      primaryContributorName: primaryContributor,
      aiSummary: aiText,
      inspectionRecommended: inspectRec,
    );
  }
}
