import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/mock_sensor_service.dart';
import '../../data/models/tank.dart';
import '../../core/widgets/app_sidebar.dart';
import '../../core/widgets/notification_bell_button.dart';

class TanksScreen extends ConsumerWidget {
  const TanksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tanksAsync = ref.watch(tanksProvider);
    final tanks = tanksAsync.value ?? MockSensorService.instance.getTanks();
    final role = ref.watch(userRoleProvider);

    Widget mainScreen = Scaffold(
      backgroundColor: AppConstants.darkBackground,
      appBar: AppBar(
        title: const Text('Institutional Water Storage Tanks'),
        actions: [
          const NotificationBellButton(),
          if (role == UserRole.admin)
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: AppConstants.accentCyan),
              onPressed: () => context.push('/add-tank'),
            ),
        ],
      ),
      body: tanks.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.water_damage_outlined, size: 64, color: Colors.white38),
                  const SizedBox(height: 16),
                  const Text('No tanks available', style: TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add New Tank'),
                    onPressed: () => context.push('/add-tank'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: tanks.length,
              itemBuilder: (context, index) {
                final tank = tanks[index];
                return _buildTankCard(context, ref, tank);
              },
            ),
    );

    return Scaffold(
      backgroundColor: AppConstants.darkBackground,
      body: Row(
        children: [
          const AppSidebar(activeRoute: '/tanks'),
          const VerticalDivider(color: AppConstants.darkCardBorder, width: 1),
          Expanded(child: mainScreen),
        ],
      ),
    );
  }

  Widget _buildTankCard(BuildContext context, WidgetRef ref, Tank tank) {
    final aiAsync = ref.watch(aiAnalysisProvider(tank.id));
    final aiData = aiAsync.value ?? MockSensorService.instance.getAIAnalysis(tank.id);
    final scoreColor = AppConstants.getScoreColor(aiData.waterQualityScore);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppConstants.darkCardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      ref.read(selectedTankProvider.notifier).state = tank;
                      context.push('/tank-details', extra: tank.id);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Row(
                      children: [
                        const Icon(Icons.water_rounded, color: AppConstants.accentCyan),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            tank.tankName,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: scoreColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${aiData.waterQualityScore}/100 (${aiData.status})',
                        style: TextStyle(
                          color: scoreColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: () => _confirmDeleteTank(context, ref, tank),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0x33EF4444),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.delete_forever_rounded, color: Color(0xFFEF4444), size: 18),
                            SizedBox(width: 4),
                            Text(
                              'Delete',
                              style: TextStyle(
                                color: Color(0xFFEF4444),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () {
                ref.read(selectedTankProvider.notifier).state = tank;
                context.push('/tank-details', extra: tank.id);
              },
              borderRadius: BorderRadius.circular(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tank.location, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Capacity: ${tank.capacity.toStringAsFixed(0)} L', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                      Text('Cleaned: ${tank.daysSinceCleaning}d ago', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                      Text('Status: ${tank.status.name.toUpperCase()}', style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteTank(BuildContext context, WidgetRef ref, Tank tank) {
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
}
