import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/app_providers.dart';
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
      appBar: AppBar(
        title: Text(tank.tankName),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
            tooltip: 'Delete Tank',
            onPressed: () => _confirmDeleteTank(context, ref, tank),
          ),
        ],
      ),
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
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Delete This Tank', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => _confirmDeleteTank(context, ref, tank),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteTank(BuildContext context, WidgetRef ref, dynamic tank) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161F30),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF1E293B)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 24),
            ),
            const SizedBox(width: 12),
            const Text(
              'Delete Tank',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "${tank.tankName}"?',
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'This will remove all associated telemetry, logs, and sensor records for this tank. This action cannot be undone.',
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(tankRepositoryProvider).deleteTank(tank.id);
              ref.invalidate(tanksProvider);
              if (ref.read(selectedTankProvider)?.id == tank.id) {
                final remaining = ref.read(tanksProvider).value ?? [];
                ref.read(selectedTankProvider.notifier).state = remaining.isNotEmpty ? remaining.first : null;
              }
              if (context.mounted) {
                context.pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF1E293B),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    content: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, color: Colors.redAccent, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${tank.tankName} has been deleted.',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
            },
          ),
        ],
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
