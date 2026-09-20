import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/mock_sensor_service.dart';

class TankDetailScreen extends ConsumerWidget {
  final String tankId;

  const TankDetailScreen({super.key, required this.tankId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tank = MockSensorService.instance.getTankById(tankId) ?? MockSensorService.instance.getTanks().first;
    final device = MockSensorService.instance.getDeviceForTank(tank.id);
    final ai = MockSensorService.instance.getAIAnalysis(tank.id);

    return Scaffold(
      backgroundColor: AppConstants.darkBackground,
      appBar: AppBar(title: Text(tank.tankName)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppConstants.darkCardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppConstants.darkCardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tank.tankName, style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(tank.location, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const Divider(color: Colors.white24, height: 24),
                  _infoRow('Status', tank.status.name.toUpperCase(), Colors.greenAccent),
                  _infoRow('Capacity', '${tank.capacity.toStringAsFixed(0)} Liters', Colors.white),
                  _infoRow('Paired Device', tank.deviceId ?? 'None', AppConstants.accentCyan),
                  _infoRow('Power Source', device?.powerStatus.name.toUpperCase() ?? 'MAINS', Colors.white),
                  _infoRow('Last Cleaned', '${tank.daysSinceCleaning} days ago', Colors.amber),
                  _infoRow('AI Water Quality Score', '${ai.waterQualityScore} / 100 (${ai.status})', AppConstants.getScoreColor(ai.waterQualityScore)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Quick Operations', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.show_chart),
                label: const Text('View Historical Graphs'),
                onPressed: () => context.push('/graphs'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppConstants.darkSurface),
                icon: const Icon(Icons.cleaning_services),
                label: const Text('Record Cleaning & Reset AI Baseline'),
                onPressed: () => context.push('/record-cleaning'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String val, Color valColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 13)),
          Text(val, style: TextStyle(color: valColor, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}
