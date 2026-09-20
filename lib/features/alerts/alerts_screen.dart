import 'package:flutter/foundation.dart';
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
    'All': 'Showing all system notifications and telemetry alerts.',
    'Unread': 'Showing unacknowledged alerts that require technical attention.',
    'Critical': '🔴 Critical Alerts: High-severity conditions where Water Quality Index dropped into Danger (<40) or severe physical parameter breakdown occurred.',
    'Cleaning': '🧹 Cleaning Alerts: Maintenance notifications indicating turbidity spikes (>1.5 NTU), sediment buildup, or mandatory tank scrubbing intervals.',
    'Device': '📟 Device Alerts: Hardware diagnostic messages regarding sensor calibration, telemetry probe connectivity, or hardware errors.',
    'Power': '⚡ Power Alerts: Power supply notifications when mains electricity is disconnected and the monitoring station operates on Battery Backup mode.',
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

    final isDesktop = kIsWeb || MediaQuery.of(context).size.width > 500;

    Widget mainScreen = Scaffold(
      backgroundColor: AppConstants.darkBackground,
      appBar: AppBar(
        backgroundColor: AppConstants.darkBackground,
        title: const Text('Water Monitor Alert Center'),
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
          const SizedBox(height: 8),

          // Alerts List (Clickable Alert Cards)
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('No alerts found for this category.', style: TextStyle(color: Colors.white54)))
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

    final isCombinedCriticalCleaning = alert.severity == 'CRITICAL' && (alert.alertType == 'cleaning' || alert.title.toLowerCase().contains('clean'));

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: severityColor.withValues(alpha: 0.5), width: alert.severity == 'CRITICAL' ? 1.5 : 1.0),
      ),
      color: AppConstants.darkCardBackground,
      child: InkWell(
        onTap: () {
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
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: severityColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      alert.alertType == 'cleaning' ? Icons.cleaning_services_rounded : Icons.warning_amber_rounded,
                      color: severityColor,
                      size: 24,
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
                                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: severityColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                              child: Text(alert.severity, style: TextStyle(color: severityColor, fontSize: 10, fontWeight: FontWeight.bold)),
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
                              'Detected: ${alert.detectedAt.hour}:${alert.detectedAt.minute.toString().padLeft(2, '0')}',
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
