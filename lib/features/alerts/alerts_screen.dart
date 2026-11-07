import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/mock_sensor_service.dart';
import '../../data/models/alert.dart';
import '../../data/repositories/alert_repository.dart';
import '../../core/widgets/app_sidebar.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Alert category definitions (no "Critical" tab — handled by severity colour)
// ─────────────────────────────────────────────────────────────────────────────
const _categories = ['All', 'Unread', 'WiFi', 'Device', 'Power', 'Cleaning'];

const _categoryExplanations = {
  'All': 'All active system notifications from real-time sensor telemetry.',
  'Unread': 'Unacknowledged alerts requiring your attention.',
  'WiFi': 'ESP32 connectivity and ThingSpeak data stream status.',
  'Device': 'Sensor hardware diagnostics — calibration, probe faults, wiring.',
  'Power': 'Power supply health — mains, USB, stale data due to power loss.',
  'Cleaning': 'Water quality deterioration — pH, TDS, turbidity, quality score.',
};

// ─────────────────────────────────────────────────────────────────────────────
// Icon & colour helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Returns the icon for a given alert type.
IconData _alertIcon(String alertType, String severity) {
  switch (alertType) {
    case 'wifi':
      return Icons.wifi_off_rounded;
    case 'power':
      return Icons.bolt_rounded;
    case 'device':
      return Icons.memory_rounded;
    case 'cleaning':
      return Icons.water_drop_rounded;
    default:
      return Icons.notifications_active_rounded;
  }
}

/// Returns the status colour for a severity string.
/// GREEN  → safe / INFO
/// YELLOW → warning
/// RED    → critical
Color _severityColor(String severity) {
  switch (severity.toUpperCase()) {
    case 'CRITICAL':
      return const Color(0xFFEF4444); // red
    case 'WARNING':
      return const Color(0xFFFFB300); // amber / yellow
    default:
      return const Color(0xFF22C55E); // green for safe / info
  }
}

/// Returns the icon for the system-level status dot.
IconData _systemStatusIcon(String status) {
  switch (status) {
    case 'critical':
      return Icons.error_rounded;
    case 'warning':
      return Icons.warning_amber_rounded;
    default:
      return Icons.check_circle_rounded;
  }
}

Color _systemStatusColor(String status) {
  switch (status) {
    case 'critical':
      return const Color(0xFFEF4444);
    case 'warning':
      return const Color(0xFFFFB300);
    default:
      return const Color(0xFF22C55E); // green
  }
}

String _systemStatusLabel(String status) {
  switch (status) {
    case 'critical':
      return 'Critical — Action Required';
    case 'warning':
      return 'Warning — Attention Needed';
    default:
      return 'All Systems Safe';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(alertRepositoryProvider).markAllAsRead();
      ref.invalidate(alertsProvider);
    });
  }

  // ── Category filtering ────────────────────────────────────────────────────

  List<AlertItem> _filter(List<AlertItem> list) {
    if (_selectedCategory == 'All') return list;
    if (_selectedCategory == 'Unread') return list.where((a) => !a.isRead).toList();
    final key = _selectedCategory.toLowerCase();
    return list.where((a) => a.alertType == key).toList();
  }

  int _count(List<AlertItem> list, String cat) {
    if (cat == 'All') return list.length;
    if (cat == 'Unread') return list.where((a) => !a.isRead).length;
    return list.where((a) => a.alertType == cat.toLowerCase()).length;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final alertsAsync = ref.watch(alertsProvider);
    final alertList = alertsAsync.value ?? MockSensorService.instance.getAlerts();
    final filtered = _filter(alertList);

    // Compute overall system status from active alert list
    final systemStatus = AlertRepository.computeSystemStatus(alertList);
    final statusColor = _systemStatusColor(systemStatus);

    Widget mainScreen = Scaffold(
      backgroundColor: AppConstants.darkBackground,
      appBar: AppBar(
        backgroundColor: AppConstants.darkBackground,
        title: const Text('Water Monitor Alert Centre'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.done_all_rounded, color: AppConstants.accentCyan, size: 18),
            label: const Text(
              'Mark All Read',
              style: TextStyle(
                  color: AppConstants.accentCyan, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              ref.read(alertRepositoryProvider).markAllAsRead();
              ref.invalidate(alertsProvider);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('All alerts marked as read.'),
                    duration: Duration(seconds: 2)),
              );
            },
          ),
          TextButton.icon(
            icon: const Icon(Icons.delete_sweep_rounded, color: Color(0xFFEF4444), size: 18),
            label: const Text(
              'Clear All',
              style: TextStyle(
                  color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              ref.read(alertRepositoryProvider).clearAllAlerts();
              ref.invalidate(alertsProvider);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('All notifications cleared.'),
                    duration: Duration(seconds: 2)),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // ── System Status Banner (Green / Yellow / Red) ──────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: statusColor.withValues(alpha: 0.5), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withValues(alpha: 0.15),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Pulsing status dot
                  _StatusDot(color: statusColor),
                  const SizedBox(width: 10),
                  Icon(_systemStatusIcon(systemStatus), color: statusColor, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _systemStatusLabel(systemStatus),
                          style: GoogleFonts.inter(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '${alertList.length} active alert${alertList.length == 1 ? '' : 's'} · '
                          '${alertList.where((a) => !a.isRead).length} unread',
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  // Refresh button
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white54, size: 20),
                    tooltip: 'Refresh alerts',
                    onPressed: () => ref.invalidate(alertsProvider),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ),

          // ── Category Filter Chips ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categories.map((cat) {
                  final count = _count(alertList, cat);
                  final isSelected = _selectedCategory == cat;

                  // Chip accent colour based on highest severity in that category
                  final catAlerts = cat == 'All'
                      ? alertList
                      : cat == 'Unread'
                          ? alertList.where((a) => !a.isRead).toList()
                          : alertList.where((a) => a.alertType == cat.toLowerCase()).toList();
                  final chipStatus = AlertRepository.computeSystemStatus(catAlerts);
                  final chipColor = isSelected
                      ? _systemStatusColor(chipStatus)
                      : Colors.white38;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedCategory = cat),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? chipColor.withValues(alpha: 0.18)
                              : AppConstants.darkCardBackground,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? chipColor
                                : AppConstants.darkCardBorder,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Chip icon coloured by severity
                            Icon(
                              _chipIcon(cat, catAlerts),
                              color: chipColor,
                              size: 15,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              cat,
                              style: TextStyle(
                                color: isSelected ? chipColor : Colors.white70,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                            if (count > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: chipColor.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$count',
                                  style: TextStyle(
                                    color: chipColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // ── Category explanation ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppConstants.darkSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppConstants.darkCardBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: AppConstants.accentCyan, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _categoryExplanations[_selectedCategory] ?? '',
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),

          // ── Alert List ───────────────────────────────────────────────────
          Expanded(
            child: filtered.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) =>
                        _buildAlertCard(context, filtered[index]),
                  ),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: AppConstants.darkBackground,
      body: Row(
        children: [
          const AppSidebar(activeRoute: '/alerts'),
          const VerticalDivider(color: AppConstants.darkCardBorder, width: 1),
          Expanded(child: mainScreen),
        ],
      ),
    );
  }

  // ── Chip icon (reflects severity of that category) ────────────────────────
  IconData _chipIcon(String cat, List<AlertItem> catAlerts) {
    final status = AlertRepository.computeSystemStatus(catAlerts);
    if (cat == 'All') {
      if (status == 'critical') return Icons.error_rounded;
      if (status == 'warning') return Icons.warning_amber_rounded;
      return Icons.check_circle_rounded;
    }
    switch (cat) {
      case 'Unread':
        return Icons.mark_email_unread_rounded;
      case 'WiFi':
        return catAlerts.isNotEmpty ? Icons.wifi_off_rounded : Icons.wifi_rounded;
      case 'Device':
        return Icons.memory_rounded;
      case 'Power':
        return Icons.bolt_rounded;
      case 'Cleaning':
        return Icons.water_drop_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  // ── Empty state ───────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.4),
                  width: 2),
            ),
            child: const Icon(Icons.check_circle_outline_rounded,
                color: Color(0xFF22C55E), size: 36),
          ),
          const SizedBox(height: 14),
          Text(
            _selectedCategory == 'All'
                ? 'All Systems Clear'
                : 'No $_selectedCategory Alerts',
            style: GoogleFonts.inter(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            _selectedCategory == 'All'
                ? 'All sensors are operating normally.'
                : 'No issues detected in this category.',
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ── Alert card ────────────────────────────────────────────────────────────
  Widget _buildAlertCard(BuildContext context, AlertItem alert) {
    final severityColor = _severityColor(alert.severity);
    final icon = _alertIcon(alert.alertType, alert.severity);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: alert.isRead
              ? severityColor.withValues(alpha: 0.25)
              : severityColor.withValues(alpha: 0.85),
          width: alert.isRead ? 1.0 : 1.8,
        ),
      ),
      color: AppConstants.darkCardBackground,
      child: InkWell(
        onTap: () {
          ref.read(alertRepositoryProvider).markAsRead(alert.id);
          ref.invalidate(alertsProvider);
          context.push('/alert-details', extra: {
            'title': alert.title,
            'message': alert.message,
            'severity': alert.severity,
            'alertType': alert.alertType,
            'detectedAt': alert.detectedAt.toIso8601String(),
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Coloured icon circle ──────────────────────────────────
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: severityColor.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: severityColor.withValues(alpha: 0.5), width: 1.5),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: severityColor, size: 22),
              ),
              const SizedBox(width: 12),

              // ── Content ───────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            alert.title,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // NEW badge
                        if (!alert.isRead) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF3D00).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: const Color(0xFFFF3D00), width: 0.8),
                            ),
                            child: const Text('NEW',
                                style: TextStyle(
                                    color: Color(0xFFFF3D00),
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 6),
                        ],
                        // Severity badge (colour-coded)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: severityColor.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: severityColor.withValues(alpha: 0.4),
                                width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                alert.severity == 'CRITICAL'
                                    ? Icons.error_rounded
                                    : alert.severity == 'WARNING'
                                        ? Icons.warning_amber_rounded
                                        : Icons.info_rounded,
                                color: severityColor,
                                size: 11,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                alert.severity,
                                style: TextStyle(
                                    color: severityColor,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Message
                    Text(
                      alert.message,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12, height: 1.4),
                    ),
                    const SizedBox(height: 10),

                    // Footer row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(_typeIcon(alert.alertType),
                                color: severityColor.withValues(alpha: 0.7),
                                size: 12),
                            const SizedBox(width: 4),
                            Text(
                              _typeLabel(alert.alertType),
                              style: TextStyle(
                                  color: severityColor.withValues(alpha: 0.7),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              DateFormat('h:mm a · d MMM')
                                  .format(alert.detectedAt.toLocal()),
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 10.5),
                            ),
                          ],
                        ),
                        const Row(
                          children: [
                            Text('Details',
                                style: TextStyle(
                                    color: AppConstants.accentCyan,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                            SizedBox(width: 2),
                            Icon(Icons.chevron_right_rounded,
                                color: AppConstants.accentCyan, size: 14),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'wifi':
        return Icons.wifi_off_rounded;
      case 'power':
        return Icons.bolt_rounded;
      case 'device':
        return Icons.memory_rounded;
      case 'cleaning':
        return Icons.water_drop_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'wifi':
        return 'WiFi';
      case 'power':
        return 'Power';
      case 'device':
        return 'Device';
      case 'cleaning':
        return 'Cleaning';
      default:
        return 'System';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated pulsing status dot
// ─────────────────────────────────────────────────────────────────────────────
class _StatusDot extends StatefulWidget {
  final Color color;
  const _StatusDot({required this.color});

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: _anim.value),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: _anim.value * 0.6),
              blurRadius: 6,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }
}
