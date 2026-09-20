import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _criticalAlerts = true;
  bool _cleaningAlerts = true;
  bool _trendAlerts = true;
  bool _deviceAlerts = true;
  bool _powerAlerts = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.darkBackground,
      appBar: AppBar(title: const Text('Push Notification Preferences')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Critical Deterioration Alerts', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Immediate alerts when water quality score drops below 40', style: TextStyle(color: Colors.white60, fontSize: 12)),
            value: _criticalAlerts,
            activeThumbColor: AppConstants.accentCyan,
            onChanged: (val) => setState(() => _criticalAlerts = val),
          ),
          SwitchListTile(
            title: const Text('Cleaning Recommendations', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Alerts when AI detects abnormal turbidity peak', style: TextStyle(color: Colors.white60, fontSize: 12)),
            value: _cleaningAlerts,
            activeThumbColor: AppConstants.accentCyan,
            onChanged: (val) => setState(() => _cleaningAlerts = val),
          ),
          SwitchListTile(
            title: const Text('Water Quality Trend Drift', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Gradual baseline elevation notifications', style: TextStyle(color: Colors.white60, fontSize: 12)),
            value: _trendAlerts,
            activeThumbColor: AppConstants.accentCyan,
            onChanged: (val) => setState(() => _trendAlerts = val),
          ),
          SwitchListTile(
            title: const Text('Device Offline Alerts', style: TextStyle(color: Colors.white)),
            subtitle: const Text('ESP32 telemetry disconnection alerts', style: TextStyle(color: Colors.white60, fontSize: 12)),
            value: _deviceAlerts,
            activeThumbColor: AppConstants.accentCyan,
            onChanged: (val) => setState(() => _deviceAlerts = val),
          ),
          SwitchListTile(
            title: const Text('Power Backup Notifications', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Mains failure & battery backup notifications', style: TextStyle(color: Colors.white60, fontSize: 12)),
            value: _powerAlerts,
            activeThumbColor: AppConstants.accentCyan,
            onChanged: (val) => setState(() => _powerAlerts = val),
          ),
        ],
      ),
    );
  }
}
