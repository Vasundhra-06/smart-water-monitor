import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/mock_sensor_service.dart';
import '../../core/services/thing_speak_http_service.dart';
import '../../core/widgets/notification_bell_button.dart';
import 'widgets/dashboard_historical_graph.dart';
import '../../data/models/tank.dart';
import '../../data/models/sensor_reading.dart';
import '../../data/models/ai_analysis_result.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Future<void> _confirmResetDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppConstants.darkCardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppConstants.darkCardBorder),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.restart_alt_rounded, color: Color(0xFFEF4444), size: 22),
            ),
            const SizedBox(width: 10),
            const Text(
              'Reset Sensors to 0?',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'This will clear the current graph and reset all sensor values (pH, TDS, Quality, Temp) to 0.\n\nOnce you dip your sensor into water, fresh real-time readings will immediately stream and plot in the graph.',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Confirm Reset', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ThingSpeakHttpService.instance.resetAllData();
      ref.invalidate(historicalReadingsStreamProvider('tank-main'));
      ref.invalidate(historicalReadingsProvider('tank-main'));
      ref.invalidate(liveSensorStreamProvider);
      ref.invalidate(latestReadingProvider('tank-main'));
      setState(() {});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0F1B33),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: AppConstants.accentCyan),
            ),
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppConstants.accentCyan, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Sensors reset to 0 & graph cleared! Dip sensor into water to begin streaming.',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedTank = ref.watch(selectedTankProvider);
    final tanksAsync = ref.watch(tanksProvider);
    final activeTank = selectedTank ?? MockSensorService.instance.getTanks().first;

    final isReset = ThingSpeakHttpService.instance.isResetMode;
    final latestReading = isReset
        ? SensorReading.zero(tankId: activeTank.id)
        : (ref.watch(liveSensorStreamProvider).value ??
            (ThingSpeakHttpService.instance.latestCachedReading ??
                SensorReading.zero(tankId: activeTank.id)));
    final aiAsync = ref.watch(aiAnalysisProvider(activeTank.id));
    final aiData = aiAsync.value ?? MockSensorService.instance.getAIAnalysis(activeTank.id);

    final scenario = ref.watch(simulationScenarioProvider);

    Widget mainContent = SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Deterioration Peak Warning Alert Card (If AI detects deterioration)
          if (aiData.cleaningRecommendation || scenario == SimulationScenario.deteriorating)
            _buildCleaningAlertBanner(context, activeTank, aiData),

          // Interactive Historical Trend Graph Section (Replaces Overall Score)
          DashboardHistoricalGraph(tankId: activeTank.id),
          const SizedBox(height: 24),

          // Live Updates Stale Data Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'LIVE SENSOR READINGS',
                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0),
              ),
              Text(
                'Updated ${DateTime.now().second % 15 + 1}s ago',
                style: const TextStyle(color: AppConstants.accentCyan, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 4 Live Sensor Cards Grid
          _buildSensorCardsGrid(context, latestReading),
          const SizedBox(height: 24),

          // AI Trend Overview & Quick Actions
          _buildAITrendQuickCard(context, activeTank, aiData),
          const SizedBox(height: 24),

          // Feature Quick Action Grid
          _buildQuickFeatureGrid(context, activeTank),
        ],
      ),
    );

    PreferredSizeWidget appBar = AppBar(
      backgroundColor: AppConstants.darkCardBackground,
      elevation: 0,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppConstants.accentCyan.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppConstants.accentCyan.withValues(alpha: 0.4)),
            ),
            child: const Icon(Icons.water_drop_rounded, color: AppConstants.accentCyan, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppConstants.appName,
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Flexible(
                      child: DropdownButton<String>(
                        value: activeTank.id,
                        dropdownColor: AppConstants.darkSurface,
                        underline: const SizedBox(),
                        isDense: true,
                        icon: const Icon(Icons.arrow_drop_down, color: AppConstants.accentCyan),
                        items: (tanksAsync.value ?? [activeTank]).map((tank) {
                          return DropdownMenuItem<String>(
                            value: tank.id,
                            child: Text(
                              tank.tankName,
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (id) {
                          if (id != null) {
                            final chosen = (tanksAsync.value ?? []).firstWhere((t) => t.id == id, orElse: () => activeTank);
                            ref.read(selectedTankProvider.notifier).state = chosen;
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(radius: 3, backgroundColor: Colors.greenAccent),
                          SizedBox(width: 4),
                          Text('Live', style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: ElevatedButton.icon(
            onPressed: () => _confirmResetDialog(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.18),
              foregroundColor: const Color(0xFFEF4444),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              side: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFFEF4444)),
            label: const Text(
              'Reset',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
            ),
          ),
        ),
        const SizedBox(width: 6),
        const NotificationBellButton(),
        const SizedBox(width: 12),
      ],
    );

    return Scaffold(
      backgroundColor: AppConstants.darkBackground,
      appBar: appBar,
      body: mainContent,
    );
  }

  Widget _buildCleaningAlertBanner(BuildContext context, Tank tank, AIAnalysisResult aiData) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppConstants.colorCritical.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppConstants.colorCritical, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_rounded, color: AppConstants.colorCritical, size: 24),
              const SizedBox(width: 8),
              Text(
                'ABNORMAL WATER QUALITY TREND DETECTED',
                style: GoogleFonts.inter(color: AppConstants.colorCritical, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Water quality in ${tank.tankName} is deteriorating based on turbidity/TDS historical peak analysis. Tank inspection & cleaning recommended.',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppConstants.colorCritical, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                icon: const Icon(Icons.cleaning_services_rounded, size: 16),
                label: const Text('Record Tank Cleaning', style: TextStyle(fontSize: 12)),
                onPressed: () => context.push('/record-cleaning'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSensorCardsGrid(BuildContext context, SensorReading reading) {
    final isZero = reading.isZero;

    final phStatus = isZero ? 'Standby' : (reading.ph >= 6.5 && reading.ph <= 8.5 ? 'Good' : 'Attention');
    final phColor = isZero ? Colors.white38 : (reading.ph >= 6.5 && reading.ph <= 8.5 ? AppConstants.colorGood : AppConstants.colorAttention);

    final tdsStatus = isZero ? 'Standby' : (reading.tds > 400 ? 'Attention' : 'Good');
    final tdsColor = isZero ? Colors.white38 : (reading.tds > 400 ? AppConstants.colorAttention : AppConstants.colorGood);

    final qualityColor = isZero ? Colors.white38 : AppConstants.getScoreColor(reading.waterQualityScore);

    final tempStatus = isZero ? 'Standby' : 'Good';
    final tempColor = isZero ? Colors.white38 : AppConstants.colorGood;

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildSensorCard(context, 'pH Level', isZero ? '0.0' : '${reading.ph}', phStatus, Icons.opacity, phColor, 'pH', reading.ph, '')),
            const SizedBox(width: 12),
            Expanded(child: _buildSensorCard(context, 'TDS', isZero ? '0 ppm' : '${reading.tds.toStringAsFixed(0)} ppm', tdsStatus, Icons.grain_rounded, tdsColor, 'TDS', reading.tds, 'ppm')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSensorCard(
                context,
                'Water Quality',
                isZero ? '0%' : '${reading.waterQualityScore}%',
                isZero ? 'Standby' : reading.qualityZone,
                Icons.verified_rounded,
                qualityColor,
                'Water Quality',
                reading.waterQualityScore.toDouble(),
                '%',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: _buildSensorCard(context, 'Temperature', isZero ? '0.0 °C' : '${reading.temperature.toStringAsFixed(1)} °C', tempStatus, Icons.thermostat_rounded, tempColor, 'Temperature', reading.temperature, '°C')),
          ],
        ),
      ],
    );
  }

  Widget _buildSensorCard(
    BuildContext context,
    String title,
    String value,
    String status,
    IconData icon,
    Color color,
    String paramKey,
    double rawVal,
    String unit, {
    bool isFullWidth = false,
  }) {
    return GestureDetector(
      onTap: () {
        context.push('/parameter-details', extra: {
          'parameter': paramKey,
          'value': rawVal,
          'unit': unit,
        });
      },
      child: Container(
        padding: const EdgeInsets.all(14),
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
                Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                Icon(icon, color: color, size: 20),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: GoogleFonts.inter(color: Colors.white, fontSize: isFullWidth ? 22 : 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(status, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAITrendQuickCard(BuildContext context, Tank tank, AIAnalysisResult ai) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppConstants.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppConstants.darkCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.psychology_rounded, color: AppConstants.accentCyan),
                  const SizedBox(width: 8),
                  Text('AI Water Quality Trend Engine', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              TextButton(
                onPressed: () => context.push('/graphs'),
                child: const Text('View Graphs', style: TextStyle(color: AppConstants.accentCyan, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(ai.summary, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.white38),
              const SizedBox(width: 6),
              Text('Days Since Last Cleaning: ${tank.daysSinceCleaning} days', style: const TextStyle(color: Colors.white60, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickFeatureGrid(BuildContext context, Tank tank) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('QUICK NAVIGATION & MAINTENANCE', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildActionCard(context, 'Graphs & Trends', Icons.show_chart, () => context.push('/graphs'))),
            const SizedBox(width: 12),
            Expanded(child: _buildActionCard(context, 'Cleaning Log', Icons.cleaning_services, () => context.push('/cleaning-history'))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildActionCard(context, 'Storage Tanks', Icons.water_rounded, () => context.push('/tanks'))),
            const SizedBox(width: 12),
            Expanded(child: _buildActionCard(context, 'Alerts Log', Icons.notifications_active_rounded, () => context.push('/alerts'))),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(BuildContext context, String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: AppConstants.darkCardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppConstants.darkCardBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppConstants.accentCyan, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
          ],
        ),
      ),
    );
  }
}
