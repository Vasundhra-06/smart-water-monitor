import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_constants.dart';

class AlertDetailScreen extends StatelessWidget {
  final Map<String, dynamic>? alertData;

  const AlertDetailScreen({super.key, this.alertData});

  @override
  Widget build(BuildContext context) {
    final title = alertData?['title'] ?? 'Water Quality Alert';
    final message = alertData?['message'] ?? 'Water quality in Main Tank is deteriorating. Abnormal turbidity peak detected (4.62 NTU). Please inspect/clean tank.';
    final severity = alertData?['severity'] ?? 'WARNING';
    final alertType = alertData?['alertType'] ?? 'quality';

    Color severityColor = AppConstants.colorInfo;
    if (severity == 'WARNING') severityColor = AppConstants.colorAttention;
    if (severity == 'CRITICAL') severityColor = AppConstants.colorCritical;

    return Scaffold(
      backgroundColor: AppConstants.darkBackground,
      appBar: AppBar(
        backgroundColor: AppConstants.darkBackground,
        title: const Text('Alert Details & AI Root Cause'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Severity Header Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: severityColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: severityColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            alertType == 'cleaning' ? Icons.cleaning_services_rounded : Icons.warning_amber_rounded,
                            color: severityColor,
                            size: 26,
                          ),
                          const SizedBox(width: 10),
                          Text(title, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: severityColor, borderRadius: BorderRadius.circular(12)),
                        child: Text(severity, style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // AI Diagnostic Parameter Impact Analysis
            Text('PARAMETER DEVIATION ANALYSIS', style: GoogleFonts.inter(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
            const SizedBox(height: 10),

            _paramAnalysisCard('Turbidity', '4.62 NTU', '0.0 – 1.5 NTU', 'HIGH IMPACT (-22 pts)', const Color(0xFFFF3D00), 'Turbidity peak detected due to sediment accumulation.'),
            _paramAnalysisCard('TDS', '342 ppm', '100 – 300 ppm', 'MODERATE IMPACT (-9 pts)', const Color(0xFFFFB300), 'Dissolved solids elevated above optimal baseline.'),
            _paramAnalysisCard('pH Level', '7.82', '6.5 – 8.5', 'NORMAL (0 pts)', const Color(0xFF00E676), 'pH remains safe and neutral.'),
            _paramAnalysisCard('Temperature', '26.5 °C', '20.0 – 28.0 °C', 'NORMAL (0 pts)', const Color(0xFF00E676), 'Optimal thermal storage.'),
            _paramAnalysisCard('Water Storage Level', '78 %', '30 – 100 %', 'NORMAL (0 pts)', const Color(0xFF00E676), 'Adequate water reserve.'),

            const SizedBox(height: 24),

            // Action Protocol
            Text('RECOMMENDED ACTION PROTOCOL', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            _protocolItem(Icons.search, 'Inspect Tank Intake & Sediment Baffles'),
            _protocolItem(Icons.cleaning_services_rounded, 'Perform Tank Scrubbing & Chlorination Wash'),
            _protocolItem(Icons.refresh_rounded, 'Recalibrate Sensor Baselines Post-Cleaning'),

            const SizedBox(height: 32),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: AppConstants.accentCyan), padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: () => context.push('/graphs'),
                    child: const Text('VIEW TREND GRAPH', style: TextStyle(color: AppConstants.accentCyan, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF3D00), padding: const EdgeInsets.symmetric(vertical: 14)),
                    icon: const Icon(Icons.cleaning_services),
                    label: const Text('RECORD CLEANING', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => context.push('/record-cleaning'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _paramAnalysisCard(String name, String currentVal, String expected, String impact, Color impactColor, String note) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppConstants.darkCardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppConstants.darkCardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(width: 8),
                    Text(currentVal, style: TextStyle(color: impactColor, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(note, style: const TextStyle(color: Colors.white60, fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: impactColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
            child: Text(impact, style: TextStyle(color: impactColor, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _protocolItem(IconData icon, String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppConstants.darkSurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppConstants.accentCyan, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
