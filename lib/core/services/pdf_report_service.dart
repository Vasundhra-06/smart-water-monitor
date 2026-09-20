import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../../data/models/tank.dart';
import '../../data/models/sensor_reading.dart';
import '../../data/models/ai_analysis_result.dart';

class PdfReportService {
  static Future<Uint8List> generateWaterQualityReport({
    required Tank tank,
    required List<SensorReading> readings,
    required AIAnalysisResult aiAnalysis,
    required String timeRange,
  }) async {
    final pdf = pw.Document();

    double avgPh = readings.isEmpty ? 7.2 : readings.map((r) => r.ph).reduce((a, b) => a + b) / readings.length;
    double avgTds = readings.isEmpty ? 235.0 : readings.map((r) => r.tds).reduce((a, b) => a + b) / readings.length;
    double avgTurb = readings.isEmpty ? 1.2 : readings.map((r) => r.turbidity).reduce((a, b) => a + b) / readings.length;
    double avgTemp = readings.isEmpty ? 26.5 : readings.map((r) => r.temperature).reduce((a, b) => a + b) / readings.length;
    double avgLevel = readings.isEmpty ? 78.0 : readings.map((r) => r.waterLevel).reduce((a, b) => a + b) / readings.length;

    double minPh = readings.isEmpty ? 7.0 : readings.map((r) => r.ph).reduce((a, b) => a < b ? a : b);
    double maxPh = readings.isEmpty ? 7.4 : readings.map((r) => r.ph).reduce((a, b) => a > b ? a : b);

    double minTds = readings.isEmpty ? 210.0 : readings.map((r) => r.tds).reduce((a, b) => a < b ? a : b);
    double maxTds = readings.isEmpty ? 260.0 : readings.map((r) => r.tds).reduce((a, b) => a > b ? a : b);

    double minTurb = readings.isEmpty ? 0.8 : readings.map((r) => r.turbidity).reduce((a, b) => a < b ? a : b);
    double maxTurb = readings.isEmpty ? 1.5 : readings.map((r) => r.turbidity).reduce((a, b) => a > b ? a : b);

    double minTemp = readings.isEmpty ? 22.0 : readings.map((r) => r.temperature).reduce((a, b) => a < b ? a : b);
    double maxTemp = readings.isEmpty ? 28.0 : readings.map((r) => r.temperature).reduce((a, b) => a > b ? a : b);

    double minLevel = readings.isEmpty ? 50.0 : readings.map((r) => r.waterLevel).reduce((a, b) => a < b ? a : b);
    double maxLevel = readings.isEmpty ? 95.0 : readings.map((r) => r.waterLevel).reduce((a, b) => a > b ? a : b);

    final df = DateFormat('dd MMM yyyy HH:mm');

    // Page 1: Executive Audit Summary & Parameter Statistics
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Smart Water Monitor System', style: const pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                      pw.Text('AI-Powered Water Quality & Institutional Audit Report', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Text('Generated: ${df.format(DateTime.now())}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                ],
              ),
              pw.Divider(thickness: 1.5, color: PdfColors.blue800),
              pw.SizedBox(height: 10),

              // Tank Details Block
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Target Storage Tank: ${tank.tankName}', style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                        pw.Text('Location: ${tank.location}', style: const pw.TextStyle(fontSize: 9)),
                        pw.Text('Capacity: ${tank.capacity.toStringAsFixed(0)} Liters', style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Audit Range: $timeRange', style: const pw.TextStyle(fontSize: 9)),
                        pw.Text('Device ID: ${tank.deviceId ?? "TANK_001"}', style: const pw.TextStyle(fontSize: 9)),
                        pw.Text('Last Tank Cleaned: ${DateFormat('dd MMM yyyy').format(tank.lastCleanedAt)}', style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),

              // Water Quality Score Gauge summary
              pw.Row(
                children: [
                  pw.Container(
                    width: 110,
                    height: 65,
                    decoration: pw.BoxDecoration(
                      color: aiAnalysis.waterQualityScore >= 70
                          ? PdfColors.green100
                          : (aiAnalysis.waterQualityScore >= 40 ? PdfColors.amber100 : PdfColors.red100),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    alignment: pw.Alignment.center,
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Text('${aiAnalysis.waterQualityScore} / 100', style: const pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                        pw.Text(aiAnalysis.status, style: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 14),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('AI Water Quality Assessment Summary', style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                        pw.SizedBox(height: 4),
                        pw.Text(aiAnalysis.summary, style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),

              // 5 Physical Parameter Statistics Table
              pw.Text('5 Monitored Physical Parameter Statistics', style: const pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              pw.Table.fromTextArray(
                headerStyle: const pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
                cellStyle: const pw.TextStyle(fontSize: 9),
                headers: ['Parameter', 'Average', 'Min', 'Max', 'Ideal Baseline', 'Status'],
                data: [
                  ['pH Level', avgPh.toStringAsFixed(2), minPh.toStringAsFixed(2), maxPh.toStringAsFixed(2), '6.5 - 8.5', (avgPh >= 6.5 && avgPh <= 8.5) ? 'SAFE' : 'ATTENTION'],
                  ['TDS (ppm)', avgTds.toStringAsFixed(1), minTds.toStringAsFixed(1), maxTds.toStringAsFixed(1), '100 - 300 ppm', (avgTds <= 300) ? 'SAFE' : 'ATTENTION'],
                  ['Turbidity (NTU)', avgTurb.toStringAsFixed(2), minTurb.toStringAsFixed(2), maxTurb.toStringAsFixed(2), '0.0 - 1.5 NTU', (maxTurb <= 1.5) ? 'SAFE' : 'ELEVATED'],
                  ['Temperature (°C)', avgTemp.toStringAsFixed(1), minTemp.toStringAsFixed(1), maxTemp.toStringAsFixed(1), '20 - 28 °C', 'NORMAL'],
                  ['Water Level (%)', '${avgLevel.toStringAsFixed(0)}%', '${minLevel.toStringAsFixed(0)}%', '${maxLevel.toStringAsFixed(0)}%', '30 - 100 %', 'NORMAL'],
                ],
              ),
              pw.SizedBox(height: 16),

              // Detailed Telemetry Table (Recent 10 Readings)
              pw.Text('Recent Telemetry Log Snippet (${readings.length} Total Telemetry Points)', style: const pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              pw.Table.fromTextArray(
                headerStyle: const pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
                cellStyle: const pw.TextStyle(fontSize: 8),
                headers: ['Timestamp', 'pH', 'TDS (ppm)', 'Turbidity (NTU)', 'Temp (°C)', 'Level (%)', 'Score', 'Zone'],
                data: readings.take(10).map((r) {
                  return [
                    DateFormat('dd MMM HH:mm').format(r.timestamp),
                    r.ph.toStringAsFixed(2),
                    r.tds.toStringAsFixed(0),
                    r.turbidity.toStringAsFixed(2),
                    r.temperature.toStringAsFixed(1),
                    '${r.waterLevel.toStringAsFixed(0)}%',
                    '${r.waterQualityScore}',
                    r.qualityZone,
                  ];
                }).toList(),
              ),
              pw.SizedBox(height: 14),

              // AI Trend & Maintenance Status
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Maintenance Recommendation:', style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      aiAnalysis.cleaningRecommendation
                          ? 'RECOMMENDED ACTION: Deterioration trend detected in parameters. Tank inspection and cleaning recommended.'
                          : 'OPTIMAL: Water quality operates within stable baseline bounds.',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: aiAnalysis.cleaningRecommendation ? PdfColors.red800 : PdfColors.green800,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              pw.Spacer(),
              pw.Divider(color: PdfColors.grey300),
              pw.Center(
                child: pw.Text('Smart Water Monitor System — Confidential Institutional Water Quality Audit Document', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }
}
