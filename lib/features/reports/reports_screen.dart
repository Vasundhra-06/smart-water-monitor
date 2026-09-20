import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/mock_sensor_service.dart';
import '../../core/services/pdf_report_service.dart';
import '../../core/widgets/app_sidebar.dart';
import '../../core/widgets/notification_bell_button.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String _reportRange = '30 Days Audit';
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    final selectedTank = ref.watch(selectedTankProvider);
    final activeTank = selectedTank ?? MockSensorService.instance.getTanks().first;
    final readings = MockSensorService.instance.getReadingsForTank(activeTank.id);
    final ai = MockSensorService.instance.getAIAnalysis(activeTank.id);

    final isDesktop = kIsWeb || MediaQuery.of(context).size.width > 500;

    Widget mainScreen = Scaffold(
      backgroundColor: AppConstants.darkBackground,
      appBar: AppBar(
        backgroundColor: AppConstants.darkBackground,
        title: const Text('Water Quality Audit Reports'),
        actions: const [
          NotificationBellButton(),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Report Configuration Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppConstants.darkCardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppConstants.darkCardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('REPORT CONFIGURATION', style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Audit Timeframe:', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                      DropdownButton<String>(
                        value: _reportRange,
                        dropdownColor: AppConstants.darkSurface,
                        underline: const SizedBox(),
                        style: const TextStyle(color: AppConstants.accentCyan, fontWeight: FontWeight.bold, fontSize: 13),
                        items: ['Today Audit', '7 Days Audit', '30 Days Audit', 'Full Historical Log'].map((r) {
                          return DropdownMenuItem(value: r, child: Text(r));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _reportRange = val);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Text('AUDIT DATA INCLUDED IN PDF', style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
            const SizedBox(height: 12),
            _previewRow('Storage Tank:', activeTank.tankName),
            _previewRow('5 Physical Parameters:', 'pH, TDS, Turbidity, Temp, Level'),
            _previewRow('Telemetry Sample Size:', '${readings.length} Telemetry Points'),
            _previewRow('AI Diagnostics Summary:', ai.status),
            _previewRow('Cleaning Status:', ai.cleaningRecommendation ? 'NEEDS CLEANING' : 'OPTIMAL'),
            const SizedBox(height: 24),

            if (_isGenerating)
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(color: AppConstants.accentCyan),
                    SizedBox(height: 12),
                    Text('Compiling Multi-Page PDF Document...', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              )
            else ...[
              // Button 1: Download PDF File Direct Share
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.accentCyan,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16)),
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Export & Download PDF File', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  onPressed: () => _handlePdfExport(activeTank, readings, ai, isDownload: true),
                ),
              ),
              const SizedBox(height: 12),

              // Button 2: Print & Layout PDF Preview
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppConstants.accentCyan),
                    padding: const EdgeInsets.symmetric(vertical: 16)),
                  icon: const Icon(Icons.print_rounded, color: AppConstants.accentCyan),
                  label: const Text('Print / Preview PDF Audit Report', style: TextStyle(color: AppConstants.accentCyan, fontWeight: FontWeight.bold, fontSize: 14)),
                  onPressed: () => _handlePdfExport(activeTank, readings, ai, isDownload: false),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: AppConstants.darkBackground,
      body: Row(
        children: [
          const AppSidebar(activeRoute: '/reports'),
          const VerticalDivider(color: AppConstants.darkCardBorder, width: 1),
          Expanded(child: mainScreen),
        ],
      ),
    );
  }

  Future<void> _handlePdfExport(activeTank, readings, ai, {required bool isDownload}) async {
    setState(() => _isGenerating = true);
    try {
      final pdfBytes = await PdfReportService.generateWaterQualityReport(
        tank: activeTank,
        readings: readings,
        aiAnalysis: ai,
        timeRange: _reportRange,
      );

      final fileName = 'Water_Quality_Report_${activeTank.tankName.replaceAll(' ', '_')}.pdf';

      if (isDownload) {
        // Trigger browser file download / OS share sheet
        await Printing.sharePdf(
          bytes: pdfBytes,
          filename: fileName,
        );
      } else {
        // Trigger print layout preview modal
        await Printing.layoutPdf(
          onLayout: (format) async => pdfBytes,
          name: fileName,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isDownload ? 'PDF report downloaded successfully!' : 'Opening PDF print preview...'),
            backgroundColor: const Color(0xFF00E676),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF report: $e'),
            backgroundColor: const Color(0xFFFF3D00),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Widget _previewRow(String label, String val) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppConstants.darkCardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppConstants.darkCardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 13)),
          Text(val, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}
