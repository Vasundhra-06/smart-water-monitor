import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/mock_sensor_service.dart';
import '../../core/widgets/app_sidebar.dart';
import '../../core/widgets/notification_bell_button.dart';
import '../../data/models/cleaning_record.dart';
import '../../data/models/tank.dart';

class CleaningHistoryScreen extends ConsumerStatefulWidget {
  const CleaningHistoryScreen({super.key});

  @override
  ConsumerState<CleaningHistoryScreen> createState() => _CleaningHistoryScreenState();
}

class _CleaningHistoryScreenState extends ConsumerState<CleaningHistoryScreen> {
  // Filter state: 'all' or specific tank ID ('tank-main', 'tank-canteen', 'tank-hostel', 'tank-ro')
  String _selectedFilterTankId = 'all';

  @override
  Widget build(BuildContext context) {
    final allTanks = ref.watch(tanksProvider).value ?? MockSensorService.instance.getTanks();
    final allRecords = MockSensorService.instance.getCleaningHistory('all');

    // Filter records according to selected filter
    final displayedRecords = _selectedFilterTankId == 'all'
        ? allRecords
        : allRecords.where((r) => r.tankId == _selectedFilterTankId).toList();

    // Map tank IDs to Tank objects for quick lookup
    final Map<String, Tank> tankMap = {for (var t in allTanks) t.id: t};
    final activeTank = tankMap[_selectedFilterTankId];

    return Scaffold(
      backgroundColor: AppConstants.darkBackground,
      appBar: AppBar(
        title: const Text('Tank Cleaning History & Logs'),
        actions: [
          const NotificationBellButton(),
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: ElevatedButton.icon(
              onPressed: () => context.push('/record-cleaning'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.accentCyan,
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.add_task_rounded, size: 18),
              label: const Text('Record Cleaning', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          const AppSidebar(activeRoute: '/cleaning-history'),
          const VerticalDivider(color: AppConstants.darkCardBorder, width: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Interactive Dual Filter Bar (Chips + Dropdown)
                  _buildTankFilterBar(allTanks, allRecords),
                  const SizedBox(height: 16),

                  // 2. Active Filter Banner (if filtered)
                  if (_selectedFilterTankId != 'all') ...[
                    _buildActiveFilterBanner(activeTank, displayedRecords.length),
                    const SizedBox(height: 16),
                  ],

                  // 3. Summary Statistics Overview Cards
                  _buildSummaryStats(allTanks, displayedRecords),
                  const SizedBox(height: 24),

                  // 4. Section Title with Count
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _selectedFilterTankId == 'all' ? Icons.layers_rounded : _getTankIcon(_selectedFilterTankId),
                            color: _selectedFilterTankId == 'all' ? AppConstants.accentCyan : _getTankColor(_selectedFilterTankId),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _selectedFilterTankId == 'all'
                                ? 'All Tank Cleaning Logs (${displayedRecords.length} Total)'
                                : '${activeTank?.tankName ?? "Selected Tank"} Logs (${displayedRecords.length})',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      if (_selectedFilterTankId != 'all')
                        TextButton.icon(
                          onPressed: () => setState(() => _selectedFilterTankId = 'all'),
                          style: TextButton.styleFrom(foregroundColor: AppConstants.accentCyan),
                          icon: const Icon(Icons.clear_all_rounded, size: 16),
                          label: const Text('View All Tanks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 5. Cleaning Records List
                  displayedRecords.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: displayedRecords.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final record = displayedRecords[index];
                            final tank = tankMap[record.tankId];
                            return _buildCleaningCard(record, tank);
                          },
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TANK FILTER BAR (CHIPS + DROPDOWN)
  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------
  // TANK FILTER DROPDOWN AT LEFT CORNER
  // ---------------------------------------------------------------------------
  Widget _buildTankFilterBar(List<Tank> tanks, List<CleaningRecord> allRecords) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: AppConstants.darkCardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppConstants.accentCyan.withValues(alpha: 0.4), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.filter_alt_rounded, size: 18, color: AppConstants.accentCyan),
            const SizedBox(width: 8),
            Text(
              'Filter:',
              style: GoogleFonts.inter(
                color: Colors.white60,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedFilterTankId,
                dropdownColor: const Color(0xFF0F1B33),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppConstants.accentCyan),
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
                onChanged: (String? newId) {
                  if (newId != null) {
                    setState(() => _selectedFilterTankId = newId);
                  }
                },
                items: [
                  DropdownMenuItem<String>(
                    value: 'all',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.layers_rounded, size: 16, color: AppConstants.accentCyan),
                        const SizedBox(width: 8),
                        Text('All Tanks (${allRecords.length})'),
                      ],
                    ),
                  ),
                  ...tanks.map((tank) {
                    final count = allRecords.where((r) => r.tankId == tank.id).length;
                    final color = _getTankColor(tank.id);
                    final icon = _getTankIcon(tank.id);
                    return DropdownMenuItem<String>(
                      value: tank.id,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 16, color: color),
                          const SizedBox(width: 8),
                          Text('${tank.tankName} ($count)'),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            if (_selectedFilterTankId != 'all') ...[
              const SizedBox(width: 8),
              InkWell(
                onTap: () => setState(() => _selectedFilterTankId = 'all'),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, size: 14, color: Colors.white70),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ACTIVE FILTER BANNER
  // ---------------------------------------------------------------------------
  Widget _buildActiveFilterBanner(Tank? tank, int matchCount) {
    final color = _getTankColor(tank?.id ?? '');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(_getTankIcon(tank?.id ?? ''), color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Currently Viewing: ${tank?.tankName ?? "Tank"} ($matchCount cleaning logs)',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  'Location: ${tank?.location ?? "Campus"} • Capacity: ${tank?.capacity.toStringAsFixed(0) ?? "5,000"} Liters',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Clear filter and show all tanks',
            icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
            onPressed: () => setState(() => _selectedFilterTankId = 'all'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SUMMARY KPI STATISTICS CARDS
  // ---------------------------------------------------------------------------
  Widget _buildSummaryStats(List<Tank> tanks, List<CleaningRecord> records) {
    final now = DateTime.now();
    int? mostRecentDays;
    String mostRecentTank = 'None';

    if (records.isNotEmpty) {
      final latest = records.reduce((a, b) => a.cleanedAt.isAfter(b.cleanedAt) ? a : b);
      mostRecentDays = now.difference(latest.cleanedAt).inDays;
      final tank = tanks.firstWhere((t) => t.id == latest.tankId, orElse: () => tanks.first);
      mostRecentTank = tank.tankName;
    }

    // Find tank most in need of cleaning (longest since cleaned)
    Tank? overdueTank;
    int maxDays = -1;
    for (var t in tanks) {
      if (t.daysSinceCleaning > maxDays) {
        maxDays = t.daysSinceCleaning;
        overdueTank = t;
      }
    }

    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(
            title: 'TOTAL LOGGED EVENTS',
            value: '${records.length} records',
            icon: Icons.fact_check_rounded,
            accentColor: AppConstants.accentCyan,
            subtitle: _selectedFilterTankId == 'all' ? 'Across all campus tanks' : 'For selected tank',
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _buildMetricTile(
            title: 'MOST RECENT CLEANING',
            value: mostRecentDays != null ? '$mostRecentDays days ago' : 'No records',
            icon: Icons.history_rounded,
            accentColor: AppConstants.colorGood,
            subtitle: mostRecentTank,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _buildMetricTile(
            title: 'OLDEST SINCE CLEANED',
            value: overdueTank != null ? '${overdueTank.daysSinceCleaning} days ago' : 'N/A',
            icon: Icons.warning_amber_rounded,
            accentColor: (maxDays > 20) ? AppConstants.colorCritical : AppConstants.colorAttention,
            subtitle: overdueTank?.tankName ?? 'All up-to-date',
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppConstants.darkCardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppConstants.darkCardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accentColor.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: accentColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(color: accentColor, fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 11), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CLEANING RECORD CARD
  // ---------------------------------------------------------------------------
  Widget _buildCleaningCard(CleaningRecord item, Tank? tank) {
    final tankName = tank?.tankName ?? _formatTankFallbackName(item.tankId);
    final tankColor = _getTankColor(item.tankId);
    final tankIcon = _getTankIcon(item.tankId);
    final daysAgo = DateTime.now().difference(item.cleanedAt).inDays;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppConstants.darkCardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppConstants.darkCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Tank Badge + Date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Tank Pill Badge
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    // Clicking tank badge filters by this tank!
                    setState(() => _selectedFilterTankId = item.tankId);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: tankColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: tankColor.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(tankIcon, size: 14, color: tankColor),
                        const SizedBox(width: 6),
                        Text(
                          tankName,
                          style: TextStyle(
                            color: tankColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Date Tag
              Row(
                children: [
                  const Icon(Icons.event_available_rounded, size: 14, color: Colors.white38),
                  const SizedBox(width: 5),
                  Text(
                    '${item.cleanedAt.day.toString().padLeft(2, '0')}/${item.cleanedAt.month.toString().padLeft(2, '0')}/${item.cleanedAt.year} ($daysAgo days ago)',
                    style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Technician & Verified Status
          Row(
            children: [
              const CircleAvatar(
                radius: 13,
                backgroundColor: AppConstants.primaryBlue,
                child: Icon(Icons.person_rounded, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Text(
                item.cleanedBy,
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppConstants.colorGood.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, size: 12, color: AppConstants.colorGood),
                    SizedBox(width: 4),
                    Text('Verified', style: TextStyle(color: AppConstants.colorGood, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Method Tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cleaning_services_rounded, size: 14, color: AppConstants.accentCyan),
                const SizedBox(width: 6),
                Text(
                  'Method: ${item.cleaningMethod}',
                  style: const TextStyle(color: AppConstants.accentCyan, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Detailed Notes
          Text(
            item.notes,
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: AppConstants.darkCardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppConstants.darkCardBorder),
      ),
      child: Column(
        children: [
          Icon(Icons.cleaning_services_outlined, size: 48, color: Colors.white.withValues(alpha: 0.2)),
          const SizedBox(height: 12),
          const Text('No cleaning records found for this tank', style: TextStyle(color: Colors.white60, fontSize: 15)),
          const SizedBox(height: 6),
          const Text('Tap "Record Cleaning" above to log a new cleaning event.', style: TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HELPERS FOR TANK ICONS & COLORS
  // ---------------------------------------------------------------------------
  Color _getTankColor(String tankId) {
    switch (tankId) {
      case 'tank-main':
        return AppConstants.primaryBlue;
      case 'tank-canteen':
        return const Color(0xFFFF9100); // Vibrant Amber
      case 'tank-hostel':
        return const Color(0xFF7C4DFF); // Deep Purple
      case 'tank-ro':
        return AppConstants.accentCyan; // Cyan
      default:
        return AppConstants.colorGood;
    }
  }

  IconData _getTankIcon(String tankId) {
    switch (tankId) {
      case 'tank-main':
        return Icons.business_rounded;
      case 'tank-canteen':
        return Icons.restaurant_rounded;
      case 'tank-hostel':
        return Icons.home_work_rounded;
      case 'tank-ro':
        return Icons.water_drop_rounded;
      default:
        return Icons.water_rounded;
    }
  }

  String _formatTankFallbackName(String tankId) {
    switch (tankId) {
      case 'tank-main':
        return 'Main Academic Tank';
      case 'tank-canteen':
        return 'Central Canteen Tank';
      case 'tank-hostel':
        return 'Hostel Block A Tank';
      case 'tank-ro':
        return 'Library RO Tank';
      default:
        return tankId;
    }
  }
}
