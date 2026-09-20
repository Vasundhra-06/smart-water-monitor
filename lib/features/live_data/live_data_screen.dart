import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/app_providers.dart';
import '../../data/models/sensor_reading.dart';
import '../../core/widgets/app_sidebar.dart';

class LiveDataScreen extends ConsumerWidget {
  const LiveDataScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTank = ref.watch(selectedTankProvider);
    final tankId = selectedTank?.id ?? 'tank-main';

    final latestAsync = ref.watch(latestReadingProvider(tankId));
    final liveStreamReading = ref.watch(liveSensorStreamProvider).value;

    return Scaffold(
      backgroundColor: AppConstants.darkBackground,
      body: Row(
        children: [
          const AppSidebar(activeRoute: '/live-data'),
          const VerticalDivider(color: AppConstants.darkCardBorder, width: 1),
          Expanded(
            child: Scaffold(
              backgroundColor: AppConstants.darkBackground,
              appBar: AppBar(
                backgroundColor: AppConstants.darkBackground,
                title: Text('Live Sensor Stream (${selectedTank?.tankName ?? "Main Tank"})'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: AppConstants.accentCyan),
                    onPressed: () => ref.refresh(latestReadingProvider(tankId)),
                  ),
                ],
              ),
              body: latestAsync.when(
                loading: () => const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: AppConstants.accentCyan),
                      SizedBox(height: 16),
                      Text('Loading water quality data...', style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
                error: (err, stack) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.wifi_off_rounded, color: AppConstants.colorCritical, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'Unable to retrieve water quality data.',
                          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Ensure Python backend (server.py) is running on port 8080 and connected to ThingSpeak.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryBlue),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry Connection'),
                          onPressed: () => ref.refresh(latestReadingProvider(tankId)),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (fetchedReading) {
                  final reading = liveStreamReading ?? fetchedReading;

                  final tds = reading.tds;
                  final ph = reading.ph;
                  final temp = reading.temperature;
                  final score = reading.waterQualityScore;
                  final status = reading.qualityZone;
                  final timeStr = DateFormat('hh:mm:ss a, dd MMM yyyy').format(reading.timestamp.toLocal());

                  final statusColor = AppConstants.getScoreColor(score);

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Last Updated Timestamp & Data Source Banner
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppConstants.darkCardBackground,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppConstants.darkCardBorder),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.cloud_done_rounded, color: AppConstants.colorExcellent, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Source: ThingSpeak (Channel 3487158)',
                                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.access_time_rounded, color: AppConstants.accentCyan, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Last Updated: $timeStr',
                                    style: GoogleFonts.inter(color: Colors.white60, fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Water Quality Score (%) Main Banner Card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                statusColor.withValues(alpha: 0.2),
                                AppConstants.darkCardBackground,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: statusColor.withValues(alpha: 0.5), width: 1.5),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Water Quality Score (%)',
                                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '$score %',
                                    style: GoogleFonts.inter(color: statusColor, fontSize: 36, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: statusColor),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Sensor Parameter Cards
                        _buildGaugeCard('TDS (Total Dissolved Solids)', '${tds.toStringAsFixed(0)} ppm', 'Optimal (≤ 300 ppm)', AppConstants.colorGood, tds / 500),
                        const SizedBox(height: 12),
                        _buildGaugeCard('pH Level', '$ph', 'Optimal (6.5 - 8.5)', AppConstants.colorGood, (ph - 6) / 4),
                        const SizedBox(height: 12),
                        _buildGaugeCard('Temperature', '${temp.toStringAsFixed(1)} °C', 'Optimal (20 - 30 °C)', AppConstants.colorGood, temp / 40),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGaugeCard(String title, String value, String status, Color color, double percent) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppConstants.darkCardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              Text(status, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: GoogleFonts.inter(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percent.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppConstants.darkSurface,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}
