import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/app_providers.dart';
import '../../data/repositories/alert_repository.dart';

class NotificationBellButton extends ConsumerWidget {
  const NotificationBellButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(alertsProvider);
    final alerts = alertsAsync.value ?? [];
    final unreadCount = alerts.where((a) => !a.isRead).length;

    // Determine status: safe (green), warning (yellow), critical (red)
    final systemStatus = AlertRepository.computeSystemStatus(alerts);

    Color bellColor;
    IconData bellIcon;
    String statusTooltip;

    switch (systemStatus) {
      case 'critical':
        bellColor = const Color(0xFFEF4444); // Red - Critical
        bellIcon = Icons.notifications_active_rounded;
        statusTooltip = 'Critical Alerts Active';
        break;
      case 'warning':
        bellColor = const Color(0xFFFFB300); // Yellow - Warning
        bellIcon = Icons.notifications_active_rounded;
        statusTooltip = 'Warning Alerts Active';
        break;
      default:
        bellColor = const Color(0xFF22C55E); // Green - Safe
        bellIcon = Icons.notifications_none_rounded;
        statusTooltip = 'All Systems Safe';
        break;
    }

    return Tooltip(
      message: unreadCount > 0
          ? '$unreadCount Unread Alerts ($statusTooltip)'
          : statusTooltip,
      child: Stack(
        alignment: Alignment.center,
        children: [
          IconButton(
            icon: Icon(bellIcon, color: bellColor, size: 24),
            onPressed: () {
              ref.read(alertRepositoryProvider).markAllAsRead();
              ref.invalidate(alertsProvider);
              context.push('/alerts');
            },
          ),
          if (unreadCount > 0)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: bellColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: bellColor.withValues(alpha: 0.5),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
