import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/mock_sensor_service.dart';
import '../../core/widgets/notification_bell_button.dart';

class DeviceDetailsScreen extends ConsumerWidget {
  const DeviceDetailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTank = ref.watch(selectedTankProvider);
    final tankId = selectedTank?.id ?? 'tank-main';

    final device = MockSensorService.instance.getDeviceForTank(tankId);
    final isOnline = device?.isOnline ?? true;

    return Scaffold(
      backgroundColor: AppConstants.darkBackground,
      appBar: AppBar(
        title: Text('ESP32 Device Status (${device?.deviceId ?? "TANK_001"})'),
        actions: const [
          NotificationBellButton(),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppConstants.darkCardBackground,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isOnline ? AppConstants.colorGood : AppConstants.colorCritical),
              ),
              child: Column(
                children: [
                  Icon(Icons.router_rounded, color: isOnline ? AppConstants.colorGood : AppConstants.colorCritical, size: 48),
                  const SizedBox(height: 12),
                  Text(device?.deviceName ?? 'ESP32 Main Academic Unit', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('Device ID: ${device?.deviceId ?? "TANK_001"}', style: const TextStyle(color: AppConstants.accentCyan, fontSize: 13)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(color: (isOnline ? Colors.green : Colors.red).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                    child: Text(isOnline ? 'ONLINE • Connected via Wi-Fi' : 'OFFLINE', style: TextStyle(color: isOnline ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Hardware Telemetry Breakdown
            Text('Device Telemetry & Hardware Health', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),

            _buildTile('Power Source', device?.powerStatus == PowerStatus.backup ? 'BATTERY BACKUP MODE' : 'MAINS POWER', Icons.power_rounded, device?.powerStatus == PowerStatus.backup ? AppConstants.colorAttention : AppConstants.colorGood),
            _buildTile('Battery Voltage', '${device?.batteryVoltage.toStringAsFixed(2)} V (${device?.batteryPercentage}%)', Icons.battery_charging_full_rounded, AppConstants.accentCyan),
            _buildTile('Firmware Version', device?.firmwareVersion ?? 'v1.2.4', Icons.system_update_rounded, Colors.white),
            _buildTile('Last Telemetry Ping', '12 seconds ago', Icons.timer_outlined, Colors.white70),
            _buildTile('Hardware Ingestion API', 'POST /api/v1/devices/readings', Icons.api_rounded, AppConstants.primaryBlue),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(String label, String val, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        trailing: Text(val, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }
}
