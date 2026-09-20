import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

class CalibrationScreen extends StatelessWidget {
  const CalibrationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.darkBackground,
      appBar: AppBar(title: const Text('ESP32 Hardware Sensor Calibration')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCalibrationCard('pH Probe Calibration', 'Step 1: Dip probe in pH 7.0 buffer solution.\nStep 2: Adjust VR potentiometer until reading reaches 7.00.\nStep 3: Test in pH 4.01 buffer solution.', Icons.opacity, AppConstants.accentCyan),
          const SizedBox(height: 12),
          _buildCalibrationCard('TDS Sensor Calibration', 'Step 1: Submerge TDS probe in 1413 µS/cm standard solution.\nStep 2: Calibrate K-factor multiplier in firmware settings.\nStep 3: Ensure temperature compensation is active.', Icons.grain_rounded, AppConstants.primaryBlue),
          const SizedBox(height: 12),
          _buildCalibrationCard('Turbidity Sensor Calibration', 'Step 1: Place turbidity sensor in distilled clear water (0 NTU).\nStep 2: Record analog Vout (typically 4.2V).\nStep 3: Test in 100 NTU calibration fluid to establish slope line.', Icons.filter_hdr_rounded, AppConstants.colorAttention),
        ],
      ),
    );
  }

  Widget _buildCalibrationCard(String title, String instructions, IconData icon, Color color) {
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
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 10),
          Text(instructions, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
        ],
      ),
    );
  }
}
