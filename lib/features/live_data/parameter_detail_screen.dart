import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_constants.dart';

class ParameterDetailScreen extends StatelessWidget {
  final String parameterName;
  final double value;
  final String unit;

  const ParameterDetailScreen({
    super.key,
    required this.parameterName,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.darkBackground,
      appBar: AppBar(title: Text('$parameterName Parameter Analysis')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppConstants.darkCardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppConstants.accentCyan),
              ),
              child: Column(
                children: [
                  Text(parameterName.toUpperCase(), style: const TextStyle(color: Colors.white60, fontSize: 13)),
                  const SizedBox(height: 8),
                  Text('$value $unit', style: GoogleFonts.inter(fontSize: 36, fontWeight: FontWeight.bold, color: AppConstants.accentCyan)),
                  const SizedBox(height: 8),
                  const Text('Operating within normal baseline range', style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Technical Guidance & Recommended Range', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            const Text(
              'Drinking water quality criteria specify safe bounds for institutional water storage. Abnormal increases indicate biofilm buildup or pipe degradation.',
              style: TextStyle(color: Colors.white70, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
