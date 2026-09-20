import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/mock_sensor_service.dart';
import '../../data/models/cleaning_record.dart';
import '../../core/widgets/notification_bell_button.dart';

class CleaningHistoryScreen extends ConsumerWidget {
  const CleaningHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTank = ref.watch(selectedTankProvider);
    final tankId = selectedTank?.id ?? 'tank-main';

    final historyAsync = ref.watch(cleaningHistoryProvider(tankId));
    final records = historyAsync.value ?? MockSensorService.instance.getCleaningHistory(tankId);

    return Scaffold(
      backgroundColor: AppConstants.darkBackground,
      appBar: AppBar(
        title: Text('Cleaning Log (${selectedTank?.tankName ?? "Main Tank"})'),
        actions: [
          const NotificationBellButton(),
          IconButton(
            icon: const Icon(Icons.add_task_rounded, color: AppConstants.accentCyan),
            onPressed: () => context.push('/record-cleaning'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cleaning Overview Metric Card
            _buildOverviewMetricCard(selectedTank?.daysSinceCleaning ?? 6),
            const SizedBox(height: 20),

            Text('Historical Cleaning Timeline', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),

            records.isEmpty
                ? const Center(child: Text('No past cleaning events recorded.', style: TextStyle(color: Colors.white54)))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: records.length,
                    itemBuilder: (context, index) {
                      final item = records[index];
                      return _buildCleaningCard(item);
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewMetricCard(int daysAgo) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppConstants.darkCardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppConstants.darkCardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(children: [
            const Text('DAYS SINCE CLEANED', style: TextStyle(color: Colors.white60, fontSize: 11)),
            const SizedBox(height: 4),
            Text('$daysAgo days', style: const TextStyle(color: AppConstants.accentCyan, fontWeight: FontWeight.bold, fontSize: 18)),
          ]),
          const Column(children: [
            Text('AVG STABLE PERIOD', style: TextStyle(color: Colors.white60, fontSize: 11)),
            SizedBox(height: 4),
            Text('24 days', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          ]),
        ],
      ),
    );
  }

  Widget _buildCleaningCard(CleaningRecord item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.cleaning_services_rounded, color: AppConstants.colorGood, size: 20),
                    const SizedBox(width: 8),
                    Text(item.cleanedBy, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
                Text('${item.cleanedAt.day}/${item.cleanedAt.month}/${item.cleanedAt.year}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 6),
            Text('Method: ${item.cleaningMethod}', style: const TextStyle(color: AppConstants.accentCyan, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(item.notes, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
