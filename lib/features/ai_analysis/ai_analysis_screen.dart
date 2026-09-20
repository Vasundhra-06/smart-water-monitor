import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/mock_sensor_service.dart';
import '../../data/models/ai_analysis_result.dart';
import '../../core/widgets/app_sidebar.dart';

class AIAnalysisScreen extends ConsumerWidget {
  const AIAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTank = ref.watch(selectedTankProvider);
    final tankId = selectedTank?.id ?? 'tank-main';

    final aiAsync = ref.watch(aiAnalysisProvider(tankId));
    final ai = aiAsync.value ?? MockSensorService.instance.getAIAnalysis(tankId);

    final scoreColor = AppConstants.getScoreColor(ai.waterQualityScore);
    final isDesktop = kIsWeb || MediaQuery.of(context).size.width > 500;

    Widget mainScreen = Scaffold(
      backgroundColor: AppConstants.darkBackground,
      appBar: AppBar(title: Text('AI Analysis (${selectedTank?.tankName ?? "Main Tank"})')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status & Score Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppConstants.darkCardBackground,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: scoreColor.withOpacity(0.5), width: 1.5),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.psychology_rounded, color: AppConstants.accentCyan, size: 24),
                      const SizedBox(width: 8),
                      Text('AI SYSTEM STATUS: ${ai.status}', style: GoogleFonts.inter(color: scoreColor, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('${ai.waterQualityScore}', style: GoogleFonts.inter(fontSize: 52, fontWeight: FontWeight.bold, color: scoreColor)),
                  const Text('Water Quality Composite Score', style: TextStyle(color: Colors.white60, fontSize: 12)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: AppConstants.darkSurface, borderRadius: BorderRadius.circular(12)),
                    child: Text('AI Model Confidence: ${(ai.confidence * 100).toStringAsFixed(0)}%', style: const TextStyle(color: AppConstants.accentCyan, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // AI Natural Language Summary Card
            _buildSectionHeader('AI SUMMARY & ASSESSMENT'),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppConstants.darkSurface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                ai.summary,
                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
              ),
            ),
            const SizedBox(height: 20),

            // Detected Anomalies Section
            _buildSectionHeader('DETECTED PARAMETER ANOMALIES'),
            ai.detectedAnomalies.isEmpty
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppConstants.darkCardBackground, borderRadius: BorderRadius.circular(12)),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: AppConstants.colorGood, size: 20),
                        SizedBox(width: 10),
                        Text('No statistical anomalies detected.', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  )
                : Column(
                    children: ai.detectedAnomalies.map((anom) => _buildAnomalyCard(anom)).toList(),
                  ),
            const SizedBox(height: 20),

            // Prediction Horizon & Maintenance Recommendation
            _buildSectionHeader('MAINTENANCE & CLEANING PREDICTION'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ai.cleaningRecommendation ? AppConstants.colorCritical.withOpacity(0.15) : AppConstants.colorGood.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ai.cleaningRecommendation ? AppConstants.colorCritical : AppConstants.colorGood),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(ai.cleaningRecommendation ? Icons.warning_rounded : Icons.verified_user_rounded, color: ai.cleaningRecommendation ? AppConstants.colorCritical : AppConstants.colorGood),
                      const SizedBox(width: 8),
                      Text(
                        ai.cleaningRecommendation ? 'Tank Inspection & Cleaning Required' : 'Not Currently Required',
                        style: TextStyle(color: ai.cleaningRecommendation ? AppConstants.colorCritical : AppConstants.colorGood, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(ai.predictedDeterioration, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: AppConstants.darkBackground,
      body: Row(
        children: [
          const AppSidebar(activeRoute: '/ai-analysis'),
          const VerticalDivider(color: AppConstants.darkCardBorder, width: 1),
          Expanded(child: mainScreen),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(title, style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
    );
  }

  Widget _buildAnomalyCard(AnomalyItem anomaly) {
    final color = anomaly.severity == 'HIGH' || anomaly.severity == 'CRITICAL' ? AppConstants.colorCritical : AppConstants.colorAttention;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppConstants.darkCardBackground, borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.4))),
      child: Row(
        children: [
          Icon(Icons.report_problem_outlined, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${anomaly.parameter.toUpperCase()} (${anomaly.severity})', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 2),
                Text(anomaly.reason, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
