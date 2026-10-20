import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/calibration_service.dart';
import '../../core/widgets/app_sidebar.dart';
import '../../data/models/calibration_profile.dart';

class CalibrationScreen extends ConsumerStatefulWidget {
  const CalibrationScreen({super.key});

  @override
  ConsumerState<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends ConsumerState<CalibrationScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // TDS calibration inputs
  final _tdsRefValueController = TextEditingController(text: '342.0');
  final _tdsMeasuredTempController = TextEditingController(text: '26.5');
  final _tdsMeasuredRawController = TextEditingController(text: '352.2');
  final _tdsNotesController = TextEditingController(text: 'Calibrated with fresh standard solution.');
  String _selectedSolution = '1413 µS/cm (342 ppm NaCl Standard)';

  // pH calibration inputs
  final _phNeutralVoltageController = TextEditingController(text: '2.50');
  final _phAcidVoltageController = TextEditingController(text: '3.05');
  final _phNotesController = TextEditingController(text: 'Buffer 7.00 and 4.01 two-point calibration.');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _tdsRefValueController.dispose();
    _tdsMeasuredTempController.dispose();
    _tdsMeasuredRawController.dispose();
    _tdsNotesController.dispose();
    _phNeutralVoltageController.dispose();
    _phAcidVoltageController.dispose();
    _phNotesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(calibrationProfileProvider);

    Widget content = Scaffold(
      backgroundColor: AppConstants.darkBackground,
      appBar: AppBar(
        backgroundColor: AppConstants.darkBackground,
        title: const Text('Sensor Calibration & Temperature Compensation'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppConstants.accentCyan,
          indicatorWeight: 3,
          labelColor: AppConstants.accentCyan,
          unselectedLabelColor: Colors.white60,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.show_chart_rounded, size: 18), text: 'Temp–TDS Analysis'),
            Tab(icon: Icon(Icons.grain_rounded, size: 18), text: 'TDS Calibration'),
            Tab(icon: Icon(Icons.opacity_rounded, size: 18), text: 'pH Calibration'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTemperatureTdsAnalysisTab(profile),
          _buildTdsCalibrationTab(profile),
          _buildPhCalibrationTab(profile),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: AppConstants.darkBackground,
      body: Row(
        children: [
          const AppSidebar(activeRoute: '/calibration'),
          const VerticalDivider(color: AppConstants.darkCardBorder, width: 1),
          Expanded(child: content),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 1: TEMPERATURE–TDS CALIBRATION & VALIDATION ANALYSIS
  // ===========================================================================
  Widget _buildTemperatureTdsAnalysisTab(CalibrationProfile profile) {
    final points = profile.validationPoints;

    final rawSpots = <FlSpot>[];
    final compSpots = <FlSpot>[];
    final refSpots = <FlSpot>[];

    for (var p in points) {
      rawSpots.add(FlSpot(p.temperature, p.rawTds));
      compSpots.add(FlSpot(p.temperature, p.compensatedTds));
      refSpots.add(FlSpot(p.temperature, p.referenceValue));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Active Profile Summary Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppConstants.darkCardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppConstants.accentCyan.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.verified_rounded, color: AppConstants.accentCyan, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Active Profile: ${profile.version}',
                          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: profile.isExpired
                            ? AppConstants.colorCritical.withValues(alpha: 0.2)
                            : AppConstants.colorGood.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        profile.isExpired ? 'CALIBRATION EXPIRED' : 'VALIDATED (${profile.daysRemaining}d left)',
                        style: TextStyle(
                          color: profile.isExpired ? AppConstants.colorCritical : AppConstants.colorGood,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _metricChip('Reference Standard', profile.referenceSolution),
                    _metricChip('Normalized Baseline', '${profile.referenceTemperature.toStringAsFixed(0)} °C'),
                    _metricChip('Temp Coefficient (α)', '${(profile.alphaCoefficient * 100).toStringAsFixed(1)} %/°C (${profile.alphaCoefficient})'),
                    _metricChip('K-Factor Multiplier', profile.kFactor.toStringAsFixed(4)),
                    _metricChip('Max Residual Error', '±${profile.maxResidualError.toStringAsFixed(2)} ppm'),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Operator Notes: ${profile.operatorNotes}',
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Temperature vs TDS Calibration Chart
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TEMPERATURE vs. TDS CALIBRATION CURVE',
                          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Validating ionic mobility compensation: EC25 = ECT / [1 + α × (T − 25)]',
                          style: TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Chart Legend
                Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    _legendItem(const Color(0xFFFFB300), 'Raw Uncompensated TDS (Thermal Drift)'),
                    _legendItem(AppConstants.accentCyan, 'Compensated TDS25 (Normalized)'),
                    _legendItem(const Color(0xFF00E676), 'Certified Reference (342 ppm)'),
                  ],
                ),
                const SizedBox(height: 16),

                // Line Chart
                SizedBox(
                  height: 250,
                  child: LineChart(
                    LineChartData(
                      minX: 15,
                      maxX: 40,
                      minY: 260,
                      maxY: 460,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: true,
                        getDrawingHorizontalLine: (value) => const FlLine(color: Colors.white10, strokeWidth: 1),
                        getDrawingVerticalLine: (value) => const FlLine(color: Colors.white10, strokeWidth: 1),
                      ),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 26,
                            interval: 5,
                            getTitlesWidget: (val, meta) => Text(
                              '${val.toInt()}°C',
                              style: const TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 42,
                            interval: 50,
                            getTitlesWidget: (val, meta) => Text(
                              '${val.toInt()}',
                              style: const TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border.all(color: AppConstants.darkCardBorder),
                      ),
                      lineBarsData: [
                        // Raw TDS line (Orange)
                        LineChartBarData(
                          spots: rawSpots,
                          isCurved: true,
                          color: const Color(0xFFFFB300),
                          barWidth: 2.5,
                          dotData: const FlDotData(show: true),
                        ),
                        // Compensated TDS line (Cyan)
                        LineChartBarData(
                          spots: compSpots,
                          isCurved: true,
                          color: AppConstants.accentCyan,
                          barWidth: 2.5,
                          dotData: const FlDotData(show: true),
                        ),
                        // Reference standard line (Green Dashed)
                        LineChartBarData(
                          spots: refSpots,
                          isCurved: false,
                          color: const Color(0xFF00E676),
                          barWidth: 2,
                          dashArray: [5, 4],
                          dotData: const FlDotData(show: false),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Multi-Temperature Calibration Validation Matrix Table
          Text(
            'MULTI-TEMPERATURE VALIDATION TEST MATRIX',
            style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.8),
          ),
          const SizedBox(height: 8),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppConstants.darkCardBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppConstants.darkCardBorder),
            ),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(1.2),
                1: FlexColumnWidth(1.4),
                2: FlexColumnWidth(1.6),
                3: FlexColumnWidth(1.4),
                4: FlexColumnWidth(1.2),
              },
              children: [
                TableRow(
                  decoration: const BoxDecoration(color: AppConstants.darkSurface),
                  children: [
                    _tableHeader('Temp'),
                    _tableHeader('Raw TDS'),
                    _tableHeader('Compensated'),
                    _tableHeader('Reference'),
                    _tableHeader('Residual'),
                  ],
                ),
                ...points.map((p) => TableRow(
                  children: [
                    _tableCell('${p.temperature.toStringAsFixed(0)} °C'),
                    _tableCell('${p.rawTds} ppm', color: const Color(0xFFFFB300)),
                    _tableCell('${p.compensatedTds} ppm', color: AppConstants.accentCyan),
                    _tableCell('${p.referenceValue} ppm', color: const Color(0xFF00E676)),
                    _tableCell('${p.residualError > 0 ? "+" : ""}${p.residualError} (${p.errorPercentage}%)'),
                  ],
                )),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Scientific Theory Notice
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppConstants.darkSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppConstants.accentCyan.withValues(alpha: 0.2)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: AppConstants.accentCyan, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Scientific Note: Ionic mobility increases at higher temperatures, causing raw conductivity-derived TDS to rise by ~2.0% per °C on uncompensated probes. The mathematical model EC25 = ECT / [1 + 0.020 × (T − 25)] neutralizes thermal drift, yielding a stable reference reading at 25°C.',
                    style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 2: TDS SENSOR CALIBRATION WORKFLOW
  // ===========================================================================
  Widget _buildTdsCalibrationTab(CalibrationProfile profile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFormCard(
            title: 'TDS / EC Sensor Calibration Protocol',
            subtitle: 'Calibrate the analog TDS sensor against a certified conductivity reference standard.',
            icon: Icons.grain_rounded,
            iconColor: AppConstants.primaryBlue,
            children: [
              // Reference Standard Solution Selector
              const Text('1. SELECT REFERENCE STANDARD SOLUTION', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppConstants.darkSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppConstants.darkCardBorder),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedSolution,
                    dropdownColor: AppConstants.darkSurface,
                    isExpanded: true,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    items: [
                      '1413 µS/cm (342 ppm NaCl Standard)',
                      '1000 ppm NaCl Calibration Solution',
                      '500 ppm KCl Secondary Standard',
                      'Custom Reference Standard',
                    ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedSolution = val;
                          if (val.contains('342')) _tdsRefValueController.text = '342.0';
                          if (val.contains('1000')) _tdsRefValueController.text = '1000.0';
                          if (val.contains('500')) _tdsRefValueController.text = '500.0';
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Inputs Row: Target Value & Measured Temp
              Row(
                children: [
                  Expanded(
                    child: _buildInputField(
                      controller: _tdsRefValueController,
                      label: 'Reference Standard Value (ppm)',
                      hint: '342.0',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInputField(
                      controller: _tdsMeasuredTempController,
                      label: 'Solution Temperature (°C)',
                      hint: '25.0',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Raw Sensor Reading
              _buildInputField(
                controller: _tdsMeasuredRawController,
                label: 'Current Raw Probe Reading (ppm)',
                hint: '352.0',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),

              // Notes
              _buildInputField(
                controller: _tdsNotesController,
                label: 'Calibration Notes / Batch Code',
                hint: 'Certified NIST-traceable standard lot #4891',
              ),
              const SizedBox(height: 18),

              // Calibrate Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.accentCyan,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.check_circle_rounded, color: Colors.black, size: 20),
                  label: const Text(
                    'CALCULATE & SAVE CALIBRATION PROFILE',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: () async {
                    final refVal = double.tryParse(_tdsRefValueController.text) ?? 342.0;
                    final temp = double.tryParse(_tdsMeasuredTempController.text) ?? 25.0;
                    final raw = double.tryParse(_tdsMeasuredRawController.text) ?? 342.0;

                    final updated = await CalibrationService.instance.performTdsCalibration(
                      referenceSolutionName: _selectedSolution,
                      referenceTdsValue: refVal,
                      measuredTemp: temp,
                      measuredRawTds: raw,
                      notes: _tdsNotesController.text,
                    );
                    ref.read(calibrationProfileProvider.notifier).state = updated;

                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('TDS Sensor calibrated! New K-Factor: ${updated.kFactor}'),
                        backgroundColor: const Color(0xFF0F1B33),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 3: pH SENSOR TWO-POINT BUFFER CALIBRATION
  // ===========================================================================
  Widget _buildPhCalibrationTab(CalibrationProfile profile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFormCard(
            title: 'pH Probe 2-Point Buffer Calibration Protocol',
            subtitle: 'Calibrate neutral offset (pH 7.00) and acidic slope (pH 4.01) buffer voltages.',
            icon: Icons.opacity_rounded,
            iconColor: AppConstants.accentCyan,
            children: [
              // Step 1: Buffer 7.00
              const Text('STEP 1: pH 7.00 NEUTRAL BUFFER OFFSET', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Rinse probe with distilled water. Immerse in pH 7.00 buffer and record stable voltage.', style: TextStyle(color: Colors.white54, fontSize: 11)),
              const SizedBox(height: 8),
              _buildInputField(
                controller: _phNeutralVoltageController,
                label: 'Neutral Buffer Voltage at pH 7.00 (Volts)',
                hint: '2.50',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),

              // Step 2: Buffer 4.01
              const Text('STEP 2: pH 4.01 ACIDIC BUFFER SLOPE', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Rinse thoroughly. Immerse probe in pH 4.01 buffer solution and record stable voltage.', style: TextStyle(color: Colors.white54, fontSize: 11)),
              const SizedBox(height: 8),
              _buildInputField(
                controller: _phAcidVoltageController,
                label: 'Acid Buffer Voltage at pH 4.01 (Volts)',
                hint: '3.05',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 14),

              // Notes
              _buildInputField(
                controller: _phNotesController,
                label: 'Calibration Notes / Buffer Expiry',
                hint: 'Standard buffers pH 7.00 & 4.01 at 25°C',
              ),
              const SizedBox(height: 18),

              // Calibrate Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.accentCyan,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.check_circle_rounded, color: Colors.black, size: 20),
                  label: const Text(
                    'SAVE pH 2-POINT CALIBRATION',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: () async {
                    final v7 = double.tryParse(_phNeutralVoltageController.text) ?? 2.50;
                    final v4 = double.tryParse(_phAcidVoltageController.text) ?? 3.05;

                    final updated = await CalibrationService.instance.performPhCalibration(
                      neutralVoltage7: v7,
                      acidVoltage4: v4,
                      notes: _phNotesController.text,
                    );
                    ref.read(calibrationProfileProvider.notifier).state = updated;

                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('pH 2-point buffer calibration saved successfully!'),
                        backgroundColor: Color(0xFF0F1B33),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // REUSABLE HELPER WIDGETS
  // ===========================================================================
  Widget _metricChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppConstants.darkSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppConstants.darkCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  Widget _tableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(text, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center),
    );
  }

  Widget _tableCell(String text, {Color color = Colors.white70}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
    );
  }

  Widget _buildFormCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
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
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppConstants.darkCardBorder),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
            filled: true,
            fillColor: AppConstants.darkSurface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppConstants.darkCardBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppConstants.darkCardBorder)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppConstants.accentCyan)),
          ),
        ),
      ],
    );
  }
}
