import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/mock_sensor_service.dart';
import '../../core/widgets/app_sidebar.dart';
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
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final selectedTank = ref.watch(selectedTankProvider);
    final tanksAsync = ref.watch(tanksProvider);
    final activeTank = selectedTank ?? MockSensorService.instance.getTanks().first;

    final latestReading = ref.watch(liveSensorStreamProvider).value ??
        MockSensorService.instance.getLatestReading(activeTank.id);
    final aiAsync = ref.watch(aiAnalysisProvider(activeTank.id));
    final aiData = aiAsync.value ?? MockSensorService.instance.getAIAnalysis(activeTank.id);

    final scoreColor = AppConstants.getScoreColor(aiData.waterQualityScore);
    final scenario = ref.watch(simulationScenarioProvider);

    final isDesktop = kIsWeb || MediaQuery.of(context).size.width > 500;

    Widget mainContent = SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Developer Demo Control Banner
          _buildDemoScenarioControlCard(context, ref, scenario, activeTank.id),
          const SizedBox(height: 16),

          // Deterioration Peak Warning Alert Card (If AI detects deterioration)
          if (aiData.cleaningRecommendation || scenario == SimulationScenario.deteriorating)
            _buildCleaningAlertBanner(context, activeTank, aiData),

          // Large Water Quality Score Gauge
          _buildWaterQualityScoreCard(aiData, scoreColor),
          const SizedBox(height: 20),

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

          // Interactive Historical Trend Graph Section
          DashboardHistoricalGraph(tankId: activeTank.id),
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
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppConstants.appName, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
          Row(
            children: [
              DropdownButton<String>(
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
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
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
      actions: [
        const NotificationBellButton(),
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: Colors.white),
          onPressed: () => context.push('/settings'),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: AppConstants.darkBackground,
      body: Row(
        children: [
          const AppSidebar(activeRoute: '/dashboard'),
          const VerticalDivider(color: AppConstants.darkCardBorder, width: 1),
          Expanded(
            child: Scaffold(
              backgroundColor: AppConstants.darkBackground,
              appBar: appBar,
              body: mainContent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDemoScenarioControlCard(BuildContext context, WidgetRef ref, SimulationScenario scenario, String tankId) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppConstants.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppConstants.primaryBlue.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.science_outlined, color: AppConstants.accentCyan, size: 20),
          const SizedBox(width: 8),
          const Text('Demo Mode:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButton<SimulationScenario>(
              value: scenario,
              dropdownColor: AppConstants.darkSurface,
              isExpanded: true,
              underline: const SizedBox(),
              style: const TextStyle(color: AppConstants.accentCyan, fontSize: 12, fontWeight: FontWeight.bold),
              items: const [
                DropdownMenuItem(value: SimulationScenario.normal, child: Text('Normal Water')),
                DropdownMenuItem(value: SimulationScenario.deteriorating, child: Text('Deteriorating (Abnormal Peak)')),
                DropdownMenuItem(value: SimulationScenario.critical, child: Text('Critical Water')),
                DropdownMenuItem(value: SimulationScenario.powerFailure, child: Text('Power Failure (Battery Backup)')),
                DropdownMenuItem(value: SimulationScenario.deviceOffline, child: Text('Device Offline')),
              ],
              onChanged: (sc) {
                if (sc != null) {
                  ref.read(simulationScenarioProvider.notifier).state = sc;
                  MockSensorService.instance.setScenario(sc);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Activated Demo Scenario: ${sc.name.toUpperCase()}')),
                  );
                }
              },
            ),
          ),
        ],
      ),
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

  Widget _buildWaterQualityScoreCard(AIAnalysisResult aiData, Color scoreColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppConstants.darkCardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scoreColor.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: scoreColor.withValues(alpha: 0.1),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Text('OVERALL WATER QUALITY SCORE', style: GoogleFonts.inter(color: Colors.white60, fontSize: 12, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${aiData.waterQualityScore}',
                style: GoogleFonts.inter(fontSize: 56, fontWeight: FontWeight.bold, color: scoreColor),
              ),
              Text(
                ' / 100',
                style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white38),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: scoreColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              aiData.status,
              style: GoogleFonts.inter(color: scoreColor, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Monitoring & Early Warning System • Non-certified indicative parameter score',
            style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSensorCardsGrid(BuildContext context, SensorReading reading) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildSensorCard(context, 'pH Level', '${reading.ph}', 'Good', Icons.opacity, AppConstants.colorGood, 'pH', reading.ph, '')),
            const SizedBox(width: 12),
            Expanded(child: _buildSensorCard(context, 'TDS', '${reading.tds.toStringAsFixed(0)} ppm', reading.tds > 400 ? 'Attention' : 'Good', Icons.grain_rounded, reading.tds > 400 ? AppConstants.colorAttention : AppConstants.colorGood, 'TDS', reading.tds, 'ppm')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildSensorCard(context, 'Turbidity', '${reading.turbidity.toStringAsFixed(2)} NTU', reading.turbidity > 2.5 ? 'Abnormal' : 'Good', Icons.filter_hdr_rounded, reading.turbidity > 2.5 ? AppConstants.colorCritical : AppConstants.colorGood, 'Turbidity', reading.turbidity, 'NTU')),
            const SizedBox(width: 12),
            Expanded(child: _buildSensorCard(context, 'Temperature', '${reading.temperature.toStringAsFixed(1)} °C', 'Good', Icons.thermostat_rounded, AppConstants.colorGood, 'Temperature', reading.temperature, '°C')),
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
            Expanded(child: _buildActionCard(context, 'PDF Reports', Icons.picture_as_pdf_outlined, () => context.push('/reports'))),
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
