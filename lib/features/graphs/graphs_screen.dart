import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/mock_sensor_service.dart';
import '../../core/widgets/notification_bell_button.dart';
import '../../data/models/sensor_reading.dart';
import '../dashboard/widgets/dashboard_historical_graph.dart';

class GraphsScreen extends ConsumerStatefulWidget {
  const GraphsScreen({super.key});

  @override
  ConsumerState<GraphsScreen> createState() => _GraphsScreenState();
}

class _GraphsScreenState extends ConsumerState<GraphsScreen> {
  @override
  Widget build(BuildContext context) {
    final selectedTank = ref.watch(selectedTankProvider);
    final tanksAsync = ref.watch(tanksProvider);
    final activeTank = selectedTank ?? MockSensorService.instance.getTanks().first;

    final latestReading = ref.watch(liveSensorStreamProvider).value ??
        MockSensorService.instance.getLatestReading(activeTank.id);

    PreferredSizeWidget appBar = AppBar(
      backgroundColor: AppConstants.darkCardBackground,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => context.canPop() ? context.pop() : context.go('/dashboard'),
      ),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
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
        ],
      ),
      actions: [
        const NotificationBellButton(),
        const SizedBox(width: 12),
      ],
    );

    return Scaffold(
      backgroundColor: AppConstants.darkBackground,
      appBar: appBar,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Historical Water Quality Trend Section (Matches Photo 2)
            DashboardHistoricalGraph(tankId: activeTank.id),
            const SizedBox(height: 24),

            // Live Sensor Readings Header
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
          ],
        ),
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
    String unit,
  ) {
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
                Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                Icon(icon, color: color, size: 16),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(status, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
