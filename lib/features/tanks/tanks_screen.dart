import 'package:flutter/foundation.dart';
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

    final isDesktop = kIsWeb || MediaQuery.of(context).size.width > 500;

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
      body: ListView.builder(
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
      child: InkWell(
        onTap: () {
          ref.read(selectedTankProvider.notifier).state = tank;
          context.push('/tank-details', extra: tank.id);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.water_rounded, color: AppConstants.accentCyan),
                      const SizedBox(width: 8),
                      Text(tank.tankName, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: scoreColor.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                    child: Text('${aiData.waterQualityScore}/100 (${aiData.status})', style: TextStyle(color: scoreColor, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(tank.location, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Capacity: ${tank.capacity.toStringAsFixed(0)} L', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  Text('Cleaned: ${tank.daysSinceCleaning}d ago', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  Text('Device: ${tank.deviceId ?? "None"}', style: const TextStyle(color: AppConstants.accentCyan, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
