import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/mock_sensor_service.dart';
import '../../data/models/alert.dart';
import '../../core/widgets/app_sidebar.dart';

class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  String _selectedCategory = 'All';

  final Map<String, String> _categoryExplanations = {
    'All': 'Showing all system notifications and active telemetry alerts.',
    'Unread': 'Showing unacknowledged alerts requiring technician or operator attention.',
    'Critical': 'Critical Alerts: Severe water safety failures (<50% index) or extreme chemical contamination risks.',
    'Cleaning': 'Cleaning Alerts: Overdue tank sanitization intervals (e.g. Canteen Tank) and sediment buildup notices.',
    'Device': 'Device Alerts: Hardware diagnostic messages regarding sensor calibration, telemetry probe connectivity, or hardware errors.',
    'Power': 'Power Alerts: 5V power delivery rail status, mains connection, and auxiliary battery backup telemetry.',
  };

  int _getCategoryCount(List<AlertItem> list, String cat) {
    if (cat == 'All') return list.length;
    if (cat == 'Unread') return list.where((a) => !a.isRead).length;
    if (cat == 'Critical') {
      return list.where((a) => a.severity == 'CRITICAL' || a.alertType == 'critical' || a.title.toLowerCase().contains('critical')).length;
    }
    if (cat == 'Cleaning') {
      return list.where((a) => a.alertType == 'cleaning' || a.title.toLowerCase().contains('clean') || a.message.toLowerCase().contains('clean')).length;
    }
    if (cat == 'Device') {
      return list.where((a) => a.alertType == 'device' || a.title.toLowerCase().contains('device')).length;
    }
    if (cat == 'Power') {
      return list.where((a) => a.alertType == 'power' || a.title.toLowerCase().contains('battery') || a.title.toLowerCase().contains('power')).length;
    }
    return 0;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(alertRepositoryProvider).markAllAsRead();
      ref.invalidate(alertsProvider);
    });
  }

  IconData _getCategoryIcon(String type, String severity) {
    if (type == 'cleaning') {
      return Icons.cleaning_services;
    }
    if (type == 'device') {
      return Icons.sensors;
    }
    if (type == 'power') {
      return Icons.bolt;
    }
    if (severity == 'CRITICAL' || type == 'critical') {
      return Icons.error_outline;
    }
    return Icons.warning_amber_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final alertsAsync = ref.watch(alertsProvider);
    final alertList = alertsAsync.value ?? MockSensorService.instance.getAlerts();

    final filtered = alertList.where((a) {
      if (_selectedCategory == 'All') return true;
      if (_selectedCategory == 'Unread') return !a.isRead;
      if (_selectedCategory == 'Critical') {
        return a.severity == 'CRITICAL' || a.alertType == 'critical' || a.title.toLowerCase().contains('critical');
      }
      if (_selectedCategory == 'Cleaning') {
        return a.alertType == 'cleaning' || a.title.toLowerCase().contains('clean') || a.message.toLowerCase().contains('clean');
      }
      if (_selectedCategory == 'Device') {
        return a.alertType == 'device' || a.title.toLowerCase().contains('device');
      }
      if (_selectedCategory == 'Power') {
        return a.alertType == 'power' || a.title.toLowerCase().contains('battery') || a.title.toLowerCase().contains('power');
      }
      return true;
    }).toList();

    Widget mainScreen = Scaffold(
      backgroundColor: AppConstants.darkBackground,
      appBar: AppBar(
        backgroundColor: AppConstants.darkBackground,
        title: const Text('Water Monitor Alert Center'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.done_all_rounded, color: AppConstants.accentCyan, size: 18),
            label: const Text(
              'Mark All Read',
              style: TextStyle(color: AppConstants.accentCyan, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              ref.read(alertRepositoryProvider).markAllAsRead();
              ref.invalidate(alertsProvider);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All alerts marked as read.'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          TextButton.icon(
            icon: const Icon(Icons.delete_sweep_rounded, color: Color(0xFFEF4444), size: 18),
            label: const Text(
              'Clear All',
              style: TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              ref.read(alertRepositoryProvider).clearAllAlerts();
              ref.invalidate(alertsProvider);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All notifications cleared.'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filter Category Dropdown Selector Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: AppConstants.darkCardBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppConstants.accentCyan.withValues(alpha: 0.4), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppConstants.accentCyan.withValues(alpha: 0.08),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.filter_list_rounded, color: AppConstants.accentCyan, size: 20),
                  const SizedBox(width: 10),
                  const Text(
                    'Filter Category:',
                    style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCategory,
                        dropdownColor: AppConstants.darkSurface,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppConstants.accentCyan, size: 24),
                        isExpanded: true,
                        style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        items: ['All', 'Unread', 'Critical', 'Cleaning', 'Device', 'Power'].map((cat) {
                          final count = _getCategoryCount(alertList, cat);
                          return DropdownMenuItem<String>(
                            value: cat,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  cat == 'All' ? 'All Alerts' : '$cat Alerts',
                                  style: TextStyle(
                                    color: _selectedCategory == cat ? AppConstants.accentCyan : Colors.white,
                                    fontWeight: _selectedCategory == cat ? FontWeight.bold : FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: count > 0 ? AppConstants.accentCyan.withValues(alpha: 0.2) : Colors.white10,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$count',
                                    style: TextStyle(
                                      color: count > 0 ? AppConstants.accentCyan : Colors.white38,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedCategory = val);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Category Explanation Info Banner
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppConstants.darkSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppConstants.darkCardBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppConstants.accentCyan, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _categoryExplanations[_selectedCategory] ?? '',
                      style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),

          // Clear All Notifications Bar Button inside the tab
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.12),
                      foregroundColor: const Color(0xFFEF4444),
                      side: BorderSide(color: const Color(0xFFEF4444).withValues(alpha: 0.5), width: 1.2),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.delete_sweep_rounded, size: 20, color: Color(0xFFEF4444)),
                    label: const Text(
                      'CLEAR ALL NOTIFICATIONS',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.6),
                    ),
                    onPressed: () {
                      ref.read(alertRepositoryProvider).clearAllAlerts();
                      ref.invalidate(alertsProvider);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('All notifications cleared successfully.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Alerts List (Clickable Alert Cards)
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_outline_rounded, color: AppConstants.accentCyan, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          'No alerts found in $_selectedCategory category.',
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return _buildAlertCard(context, item);
                    },
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

  Widget _buildAlertCard(BuildContext context, AlertItem alert) {
    Color severityColor = AppConstants.colorInfo;
    if (alert.severity == 'WARNING') severityColor = AppConstants.colorAttention;
    if (alert.severity == 'CRITICAL') severityColor = AppConstants.colorCritical;
    if (alert.alertType == 'power') severityColor = const Color(0xFFFFD600);

    final isCombinedCriticalCleaning = alert.severity == 'CRITICAL' && (alert.alertType == 'cleaning' || alert.title.toLowerCase().contains('clean'));

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: alert.isRead ? severityColor.withValues(alpha: 0.3) : severityColor,
          width: alert.isRead ? 1.0 : 1.6,
        ),
      ),
      color: alert.isRead ? AppConstants.darkCardBackground.withValues(alpha: 0.8) : AppConstants.darkCardBackground,
      child: InkWell(
        onTap: () {
          // Mark this individual alert as read
          ref.read(alertRepositoryProvider).markAsRead(alert.id);
          ref.invalidate(alertsProvider);

          // Open detail screen with root cause analysis & action buttons
          context.push('/alert-details', extra: {
            'title': alert.title,
            'message': alert.message,
            'severity': alert.severity,
            'alertType': alert.alertType,
            'detectedAt': alert.detectedAt.toIso8601String(),
          });
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: severityColor.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(color: severityColor.withValues(alpha: 0.4), width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      _getCategoryIcon(alert.alertType, alert.severity),
                      color: severityColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                alert.title,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (!alert.isRead) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF3D00).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFFF3D00), width: 0.8),
                                ),
                                child: const Text(
                                  'NEW',
                                  style: TextStyle(color: Color(0xFFFF3D00), fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: severityColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                alert.severity,
                                style: TextStyle(color: severityColor, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Full message text fits cleanly into card without cut-off
                        Text(
                          alert.message,
                          style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Detected: ${alert.detectedAt.hour.toString().padLeft(2, '0')}:${alert.detectedAt.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(color: Colors.white38, fontSize: 11),
                            ),
                            const Row(
                              children: [
                                Text('View Root Cause', style: TextStyle(color: AppConstants.accentCyan, fontSize: 11, fontWeight: FontWeight.bold)),
                                SizedBox(width: 4),
                                Icon(Icons.chevron_right_rounded, color: AppConstants.accentCyan, size: 14),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Action buttons if combined Critical & Cleaning alert
              if (isCombinedCriticalCleaning) ...[
                const SizedBox(height: 14),
                const Divider(color: AppConstants.darkCardBorder, height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppConstants.accentCyan),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.show_chart_rounded, size: 16, color: AppConstants.accentCyan),
                        label: const Text('VIEW TREND GRAPH', style: TextStyle(color: AppConstants.accentCyan, fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: () => context.push('/graphs'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF3D00),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.cleaning_services_rounded, size: 16),
                        label: const Text('RECORD CLEANING', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: () => context.push('/record-cleaning'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
