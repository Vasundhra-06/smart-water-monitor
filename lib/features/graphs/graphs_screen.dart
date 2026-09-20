import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/mock_sensor_service.dart';
import '../../core/services/water_quality_scoring_service.dart';
import '../../data/models/sensor_reading.dart';
import '../../data/models/cleaning_record.dart';
import '../../core/widgets/app_sidebar.dart';
import '../../core/widgets/notification_bell_button.dart';

class GraphsScreen extends ConsumerStatefulWidget {
  const GraphsScreen({super.key});

  @override
  ConsumerState<GraphsScreen> createState() => _GraphsScreenState();
}

class _GraphsScreenState extends ConsumerState<GraphsScreen> {
  String _selectedRange = '30d'; // 'today', '7d', '30d', 'custom'
  DateTime? _customFromDate;
  DateTime? _customToDate;

  @override
  Widget build(BuildContext context) {
    final selectedTank = ref.watch(selectedTankProvider);
    final tankId = selectedTank?.id ?? 'tank-main';
    final readingsAsync = ref.watch(historicalReadingsProvider(tankId));
    final cleaningAsync = ref.watch(cleaningHistoryProvider(tankId));

    final rawReadings = readingsAsync.value ?? [];
    final cleaningHistory = cleaningAsync.value ?? [];

    // Filter dataset dynamically based on active filter (Today, 7d, 30d, or Custom Range)
    final readings = _filterReadingsByRange(rawReadings);

    // Calculate score result for latest reading inside the selected date range
    final latestReading = readings.isNotEmpty
        ? readings.last
        : SensorReading(
            id: 'default',
            deviceId: 'ESP32_THINGSPEAK',
            tankId: tankId,
            timestamp: DateTime.now(),
            ph: 7.2,
            tds: 235.0,
            turbidity: 1.2,
            temperature: 26.5,
            waterLevel: 78.0,
          );
    final latestAnalysis = latestReading.scoreAnalysis;

    // Check for Danger Events in selected timeframe (Score < 40)
    final dangerReadings = readings.where((r) => r.waterQualityScore < 40).toList();
    final hasDangerEvent = dangerReadings.isNotEmpty;
    final peakDangerReading = hasDangerEvent
        ? dangerReadings.reduce((curr, next) => curr.waterQualityScore < next.waterQualityScore ? curr : next)
        : null;

    // Filter cleaning records that fall inside the selected date range
    final filteredCleaningHistory = _filterCleaningHistoryByRange(cleaningHistory);

    // Summary calculations derived strictly from selected range
    double sumScore = 0;
    int minScore = 100;
    for (var r in readings) {
      int s = r.waterQualityScore;
      if (s < minScore) minScore = s;
      sumScore += s;
    }
    int avgScore = readings.isNotEmpty ? (sumScore / readings.length).round() : 85;

    // Days since last cleaning calculation
    int daysSinceCleaning = selectedTank?.daysSinceCleaning ?? 12;

    final isDesktop = kIsWeb || MediaQuery.of(context).size.width > 500;

    Widget mainScreen = Scaffold(
      backgroundColor: AppConstants.darkBackground,
      appBar: AppBar(
        backgroundColor: AppConstants.darkBackground,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Historical Water Quality', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            Text('Overall Water Quality Trend — ${selectedTank?.tankName ?? "Main Tank"}', style: GoogleFonts.inter(fontSize: 12, color: Colors.white60)),
          ],
        ),
        actions: [
          const NotificationBellButton(),
          const SizedBox(width: 8),
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4)),
            ),
            child: const Row(
              children: [
                CircleAvatar(radius: 3, backgroundColor: Colors.greenAccent),
                SizedBox(width: 6),
                Text('Live', style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.0, -0.6),
            radius: 1.2,
            colors: [
              Color(0x1A00E5FF),
              Color(0xFF050B18),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Time Range Segmented Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.show_chart_rounded, color: AppConstants.accentCyan, size: 20),
                      const SizedBox(width: 8),
                      Text('Water Quality Index (0–100)', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildRangeChip('Today', 'today'),
                        const SizedBox(width: 4),
                        _buildRangeChip('7 Days', '7d'),
                        const SizedBox(width: 4),
                        _buildRangeChip('30 Days', '30d'),
                        const SizedBox(width: 4),
                        _buildCustomRangeChip(),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Section 24: Custom Range Active Banner Indicator
              if (_selectedRange == 'custom' && _customFromDate != null && _customToDate != null)
                _buildActiveCustomRangeBanner(),

              const SizedBox(height: 12),

              // Three Quality Zones Legend Header
              _buildZoneLegendHeader(),
              const SizedBox(height: 14),

              // Section 9: Empty State Handling when Custom range has no data
              if (readings.isEmpty)
                _buildEmptyStateCard()
              else
                // Main Interactive Unified Score Line Graph
                _buildGlassmorphismGraphCard(context, readings, filteredCleaningHistory),

              const SizedBox(height: 16),

              // Summary Glass Cards (calculated strictly from selected date range)
              _buildSummaryGlassCards(
                hasData: readings.isNotEmpty,
                currentScore: readings.isNotEmpty ? latestAnalysis.score : 0,
                currentStatus: readings.isNotEmpty ? latestAnalysis.status : 'NO DATA',
                avgScore: avgScore,
                lowestScore: readings.isNotEmpty ? minScore : 0,
                dangerEventCount: dangerReadings.length,
                daysSinceCleaning: daysSinceCleaning,
              ),
              const SizedBox(height: 16),

              // Cleaning Alert Glass Panel
              if (readings.isNotEmpty)
                _buildCleaningAlertGlassPanel(context, hasDangerEvent, peakDangerReading ?? latestReading, latestAnalysis),
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: AppConstants.darkBackground,
      body: Row(
        children: [
          const AppSidebar(activeRoute: '/graphs'),
          const VerticalDivider(color: AppConstants.darkCardBorder, width: 1),
          Expanded(child: mainScreen),
        ],
      ),
    );
  }

  // Section 6 & 11: Real Date Range Filter Algorithm
  List<SensorReading> _filterReadingsByRange(List<SensorReading> list) {
    if (list.isEmpty) return [];
    if (_selectedRange == 'today') {
      final now = DateTime.now();
      final todayList = list.where((r) =>
        r.timestamp.day == now.day &&
        r.timestamp.month == now.month &&
        r.timestamp.year == now.year
      ).toList();
      return todayList.isNotEmpty ? todayList : list.take(6).toList();
    } else if (_selectedRange == '7d') {
      final cutoff = DateTime.now().subtract(const Duration(days: 7));
      return list.where((r) => r.timestamp.isAfter(cutoff)).toList();
    } else if (_selectedRange == '30d') {
      final cutoff = DateTime.now().subtract(const Duration(days: 30));
      return list.where((r) => r.timestamp.isAfter(cutoff)).toList();
    } else if (_selectedRange == 'custom' && _customFromDate != null && _customToDate != null) {
      final start = DateTime(_customFromDate!.year, _customFromDate!.month, _customFromDate!.day, 0, 0, 0);
      final end = DateTime(_customToDate!.year, _customToDate!.month, _customToDate!.day, 23, 59, 59);

      return list.where((r) {
        return r.timestamp.isAfter(start.subtract(const Duration(seconds: 1))) &&
               r.timestamp.isBefore(end.add(const Duration(seconds: 1)));
      }).toList();
    }
    return list;
  }

  // Section 22: Cleaning History Filter
  List<CleaningRecord> _filterCleaningHistoryByRange(List<CleaningRecord> list) {
    if (_selectedRange == 'custom' && _customFromDate != null && _customToDate != null) {
      final start = DateTime(_customFromDate!.year, _customFromDate!.month, _customFromDate!.day, 0, 0, 0);
      final end = DateTime(_customToDate!.year, _customToDate!.month, _customToDate!.day, 23, 59, 59);
      return list.where((c) =>
        c.cleanedAt.isAfter(start.subtract(const Duration(seconds: 1))) &&
        c.cleanedAt.isBefore(end.add(const Duration(seconds: 1)))
      ).toList();
    }
    return list;
  }

  Widget _buildRangeChip(String label, String value) {
    final isSelected = _selectedRange == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(color: isSelected ? Colors.black : Colors.white70, fontWeight: FontWeight.bold, fontSize: 11)),
      selected: isSelected,
      selectedColor: AppConstants.accentCyan,
      backgroundColor: AppConstants.darkCardBackground,
      side: BorderSide(color: isSelected ? AppConstants.accentCyan : AppConstants.darkCardBorder),
      onSelected: (val) {
        if (val) setState(() => _selectedRange = value);
      },
    );
  }

  // Section 5 & 18: Custom Chip displaying active date range
  Widget _buildCustomRangeChip() {
    final isSelected = _selectedRange == 'custom';
    String chipLabel = 'Custom';
    if (isSelected && _customFromDate != null && _customToDate != null) {
      chipLabel = '✓ ${_customFromDate!.day} ${_getMonthName(_customFromDate!.month)} – ${_customToDate!.day} ${_getMonthName(_customToDate!.month)}';
    }

    return ChoiceChip(
      label: Text(chipLabel, style: TextStyle(color: isSelected ? Colors.black : Colors.white70, fontWeight: FontWeight.bold, fontSize: 11)),
      selected: isSelected,
      selectedColor: AppConstants.accentCyan,
      backgroundColor: AppConstants.darkCardBackground,
      side: BorderSide(color: isSelected ? AppConstants.accentCyan : AppConstants.darkCardBorder),
      onSelected: (val) {
        _openCustomDateRangeModal(context);
      },
    );
  }

  // Section 24: Active Custom Range Indicator Banner
  Widget _buildActiveCustomRangeBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppConstants.accentCyan.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppConstants.accentCyan.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.date_range_rounded, color: AppConstants.accentCyan, size: 16),
              const SizedBox(width: 8),
              Text(
                'Custom Range Active: ${_formatDateFull(_customFromDate!)} → ${_formatDateFull(_customToDate!)}',
                style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          InkWell(
            onTap: () => _openCustomDateRangeModal(context),
            child: const Text('Edit Range', style: TextStyle(color: AppConstants.accentCyan, fontSize: 11, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneLegendHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppConstants.darkCardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppConstants.darkCardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _zoneBadge('SAFE (70–100)', const Color(0xFF00E676)),
          _zoneBadge('WARNING (40–69)', const Color(0xFFFFB300)),
          _zoneBadge('DANGER (0–39)', const Color(0xFFFF3D00)),
        ],
      ),
    );
  }

  Widget _zoneBadge(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 4)]),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // Section 9: Empty State Handling
  Widget _buildEmptyStateCard() {
    final fromStr = _customFromDate != null ? _formatDateFull(_customFromDate!) : 'Selected From Date';
    final toStr = _customToDate != null ? _formatDateFull(_customToDate!) : 'Selected To Date';

    return Container(
      height: 320,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppConstants.darkCardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppConstants.darkCardBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.history_toggle_off_rounded, color: Colors.white38, size: 48),
          const SizedBox(height: 12),
          Text('No Water Quality Data', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 6),
          Text(
            'No sensor readings are available for:\n$fromStr – $toStr',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppConstants.accentCyan, foregroundColor: Colors.black),
            icon: const Icon(Icons.date_range, size: 16),
            label: const Text('Try Selecting Another Date Range'),
            onPressed: () => _openCustomDateRangeModal(context),
          ),
        ],
      ),
    );
  }

  // Section 8 & 12: Glassmorphism Line Chart
  Widget _buildGlassmorphismGraphCard(
    BuildContext context,
    List<SensorReading> readings,
    List<CleaningRecord> cleaningHistory,
  ) {
    final spots = <FlSpot>[];
    for (int i = 0; i < readings.length; i++) {
      spots.add(FlSpot(i.toDouble(), readings[i].waterQualityScore.toDouble()));
    }

    final latestScore = readings.last.waterQualityScore;
    final lineGradientColor = AppConstants.getScoreColor(latestScore);

    return Container(
      height: 380,
      padding: const EdgeInsets.fromLTRB(14, 16, 16, 14),
      decoration: BoxDecoration(
        color: AppConstants.darkCardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppConstants.darkCardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Overall Water Quality Score',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const Row(
                children: [
                  Icon(Icons.touch_app_rounded, color: AppConstants.accentCyan, size: 14),
                  SizedBox(width: 4),
                  Text('Tap any graph dot for 5-parameter impact breakdown', style: TextStyle(color: AppConstants.accentCyan, fontSize: 10, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          Expanded(
            child: Row(
              children: [
                RotatedBox(
                  quarterTurns: 3,
                  child: Text(
                    'Water Quality Score (0–100)',
                    style: GoogleFonts.inter(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: 100,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (val) => FlLine(color: Colors.white.withValues(alpha: 0.06), strokeWidth: 1),
                      ),
                      titlesData: FlTitlesData(
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            getTitlesWidget: (val, meta) {
                              if (val == 0 || val == 40 || val == 70 || val == 100) {
                                Color tc = Colors.white38;
                                if (val == 70) tc = const Color(0xFF00E676);
                                if (val == 40) tc = const Color(0xFFFF3D00);
                                return Text('${val.toInt()}', style: TextStyle(color: tc, fontSize: 10, fontWeight: FontWeight.bold));
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 22,
                            getTitlesWidget: (val, meta) {
                              int index = val.toInt();
                              if (index >= 0 && index < readings.length && (index % (readings.length > 10 ? 5 : 2) == 0)) {
                                final d = readings[index].timestamp;
                                return Text('${d.day} ${_getMonthName(d.month)}', style: const TextStyle(color: Colors.white38, fontSize: 10));
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),

                      extraLinesData: ExtraLinesData(
                        horizontalLines: [
                          HorizontalLine(
                            y: 70,
                            color: const Color(0xFF00E676).withValues(alpha: 0.5),
                            strokeWidth: 1.5,
                            dashArray: [6, 4],
                            label: HorizontalLineLabel(
                              show: true,
                              alignment: Alignment.topRight,
                              style: const TextStyle(color: Color(0xFF00E676), fontSize: 9, fontWeight: FontWeight.bold),
                              labelResolver: (line) => ' SAFE (70–100)',
                            ),
                          ),
                          HorizontalLine(
                            y: 40,
                            color: const Color(0xFFFF3D00).withValues(alpha: 0.7),
                            strokeWidth: 1.5,
                            dashArray: [6, 4],
                            label: HorizontalLineLabel(
                              show: true,
                              alignment: Alignment.bottomRight,
                              style: const TextStyle(color: Color(0xFFFF3D00), fontSize: 9, fontWeight: FontWeight.bold),
                              labelResolver: (line) => ' DANGER (<40)',
                            ),
                          ),
                        ],
                      ),

                      lineTouchData: LineTouchData(
                        enabled: true,
                        touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
                          if (event is FlTapUpEvent && response != null && response.lineBarSpots != null) {
                            final spot = response.lineBarSpots!.first;
                            int idx = spot.x.toInt();
                            if (idx >= 0 && idx < readings.length) {
                              _showParameterImpactDetailModal(context, readings[idx], readings);
                            }
                          }
                        },
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              int idx = spot.x.toInt();
                              if (idx >= 0 && idx < readings.length) {
                                final r = readings[idx];
                                final score = r.waterQualityScore;
                                return LineTooltipItem(
                                  '${r.timestamp.day} ${_getMonthName(r.timestamp.month)} ${r.timestamp.year} • ${r.timestamp.hour}:${r.timestamp.minute.toString().padLeft(2, '0')}\nWater Quality: $score / 100 (${r.qualityZone})\nTap to see why score dropped →',
                                  TextStyle(
                                    color: AppConstants.getScoreColor(score),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                );
                              }
                              return null;
                            }).whereType<LineTooltipItem>().toList();
                          },
                        ),
                      ),

                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: lineGradientColor,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              if (index >= 0 && index < readings.length) {
                                final score = readings[index].waterQualityScore;
                                Color dotColor = AppConstants.getScoreColor(score);
                                return FlDotCirclePainter(
                                  radius: score < 40 ? 6 : 4,
                                  color: dotColor,
                                  strokeWidth: 2,
                                  strokeColor: Colors.white,
                                );
                              }
                              return FlDotCirclePainter(radius: 4, color: AppConstants.accentCyan, strokeWidth: 1, strokeColor: Colors.white);
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                lineGradientColor.withValues(alpha: 0.25),
                                lineGradientColor.withValues(alpha: 0.0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Center(
            child: Text(
              'Time / Date',
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // Section 8: Summary Cards derived strictly from selected range
  Widget _buildSummaryGlassCards({
    required bool hasData,
    required int currentScore,
    required String currentStatus,
    required int avgScore,
    required int lowestScore,
    required int dangerEventCount,
    required int daysSinceCleaning,
  }) {
    final statusColor = hasData ? AppConstants.getScoreColor(currentScore) : Colors.white38;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('WATER QUALITY METRIC SUMMARY', style: GoogleFonts.inter(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _glassSummaryCard('CURRENT QUALITY', hasData ? '$currentScore / 100' : '--', currentStatus, statusColor)),
            const SizedBox(width: 10),
            Expanded(child: _glassSummaryCard('AVERAGE', hasData ? '$avgScore / 100' : '--', 'Range Trend', Colors.white)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _glassSummaryCard('LOWEST', hasData ? '$lowestScore / 100' : '--', lowestScore < 40 && hasData ? 'Danger Dip' : 'Stable', hasData ? AppConstants.getScoreColor(lowestScore) : Colors.white38)),
            const SizedBox(width: 10),
            Expanded(child: _glassSummaryCard('DANGER EVENTS', hasData ? '$dangerEventCount' : '0', dangerEventCount > 0 ? 'Requires Review' : 'None', dangerEventCount > 0 ? const Color(0xFFFF3D00) : const Color(0xFF00E676))),
            const SizedBox(width: 10),
            Expanded(child: _glassSummaryCard('LAST CLEANED', '$daysSinceCleaning Days', 'Ago', AppConstants.accentCyan)),
          ],
        ),
      ],
    );
  }

  Widget _glassSummaryCard(String title, String val, String subtitle, Color valColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppConstants.darkCardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppConstants.darkCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(val, style: GoogleFonts.inter(color: valColor, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(color: valColor.withValues(alpha: 0.8), fontSize: 10, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // Section 15: Cleaning Alert Panel
  Widget _buildCleaningAlertGlassPanel(
    BuildContext context,
    bool hasDangerEvent,
    SensorReading reading,
    WaterQualityScoreResult analysis,
  ) {
    if (hasDangerEvent || reading.waterQualityScore < 40) {
      final primary = analysis.primaryContributorName;
      final secondary = analysis.sortedDeterioratingParameters.skip(1).map((p) => p.name).join(', ');

      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFFF3D00).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFF3D00).withValues(alpha: 0.6), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF3D00), size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '⚠ WATER QUALITY DETERIORATING',
                    style: GoogleFonts.inter(color: const Color(0xFFFF3D00), fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Overall Quality: ${reading.waterQualityScore} / 100 (Danger Condition Detected)',
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text('Primary cause: $primary', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
            if (secondary.isNotEmpty)
              Text('Secondary contributors: $secondary', style: const TextStyle(color: Colors.white60, fontSize: 12)),
            const SizedBox(height: 8),
            const Text('Recommended Action: Inspect and clean the water tank.', style: TextStyle(color: Colors.white70, fontSize: 12, fontStyle: FontStyle.italic)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: AppConstants.accentCyan)),
                    onPressed: () => context.push('/alerts'),
                    child: const Text('VIEW ALERTS', style: TextStyle(color: AppConstants.accentCyan, fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF3D00)),
                    onPressed: () => context.push('/record-cleaning'),
                    child: const Text('RECORD CLEANING', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF00E676).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF00E676), size: 24),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('✓ WATER QUALITY STABLE', style: TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold, fontSize: 13)),
                SizedBox(height: 2),
                Text('All monitored parameters are currently within configured monitoring ranges and the overall trend is stable.', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Section 1, 2, 3, 13, 14, 25 & 27: Working Glassmorphism Custom Date Range Modal
  void _openCustomDateRangeModal(BuildContext context) {
    DateTime tempFrom = _customFromDate ?? DateTime.now().subtract(const Duration(days: 10));
    DateTime tempTo = _customToDate ?? DateTime.now();
    String? validationError;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppConstants.darkCardBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24.0,
                right: 24.0,
                top: 24.0,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Select Date Range', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                          const SizedBox(height: 2),
                          const Text('Choose the period you want to analyze.', style: TextStyle(color: Colors.white60, fontSize: 12)),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 24),

                  // Validation Error Message Box
                  if (validationError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3D00).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFF3D00).withValues(alpha: 0.6)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Color(0xFFFF3D00), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(validationError!, style: const TextStyle(color: Color(0xFFFF3D00), fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // FROM Date Picker Selector
                  const Text('FROM', style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: tempFrom,
                        firstDate: DateTime(2025, 1, 1),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        builder: (context, child) {
                          return Theme(
                            data: ThemeData.dark().copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: AppConstants.accentCyan,
                                surface: Color(0xFF0C162A),
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setModalState(() {
                          tempFrom = picked;
                          validationError = null;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppConstants.darkSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppConstants.darkCardBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, color: AppConstants.accentCyan, size: 18),
                          const SizedBox(width: 12),
                          Text(_formatDateFull(tempFrom), style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // TO Date Picker Selector
                  const Text('TO', style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: tempTo,
                        firstDate: DateTime(2025, 1, 1),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        builder: (context, child) {
                          return Theme(
                            data: ThemeData.dark().copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: AppConstants.accentCyan,
                                surface: Color(0xFF0C162A),
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setModalState(() {
                          tempTo = picked;
                          validationError = null;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppConstants.darkSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppConstants.darkCardBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.event_available_rounded, color: AppConstants.accentCyan, size: 18),
                          const SizedBox(width: 12),
                          Text(_formatDateFull(tempTo), style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Selected Period Summary
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppConstants.darkSurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Selected Period: ', style: TextStyle(color: Colors.white60, fontSize: 12)),
                        Text('${_formatDateFull(tempFrom)} → ${_formatDateFull(tempTo)}', style: const TextStyle(color: AppConstants.accentCyan, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Modal Action Buttons (Cancel / Apply)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(vertical: 14)),
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppConstants.accentCyan,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14)),
                          onPressed: () {
                            // Section 3 & 27: Real Validation Rules
                            if (tempTo.isBefore(tempFrom)) {
                              setModalState(() {
                                validationError = 'End date must be after the start date.';
                              });
                              return;
                            }
                            if (tempFrom.isAfter(DateTime.now())) {
                              setModalState(() {
                                validationError = 'No historical sensor data is available for the selected future period.';
                              });
                              return;
                            }

                            // Apply custom filter
                            setState(() {
                              _customFromDate = tempFrom;
                              _customToDate = tempTo;
                              _selectedRange = 'custom';
                            });
                            Navigator.pop(context);
                          },
                          child: const Text('Apply Filter', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Clickable Graph Point Modal
  void _showParameterImpactDetailModal(
    BuildContext context,
    SensorReading reading,
    List<SensorReading> fullDataset,
  ) {
    final analysis = WaterQualityScoringService.instance.calculateWaterQualityScore(
      reading,
      historical7DayReadings: fullDataset,
    );

    final score = analysis.score;
    final status = analysis.status;
    final scoreColor = AppConstants.getScoreColor(score);
    final dt = reading.timestamp;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppConstants.darkCardBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('WATER QUALITY EVENT', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.0)),
                          const SizedBox(height: 2),
                          Text(
                            '${dt.day} ${_getMonthName(dt.month)} ${dt.year} • ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 24),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: scoreColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: scoreColor),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Overall Quality', style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text('$score', style: GoogleFonts.inter(color: scoreColor, fontSize: 32, fontWeight: FontWeight.bold)),
                                const Text(' / 100', style: TextStyle(color: Colors.white38, fontSize: 18)),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: scoreColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            status,
                            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (analysis.sortedDeterioratingParameters.isNotEmpty) ...[
                    Text('WHY DID THE SCORE DROP?', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.0)),
                    const SizedBox(height: 12),
                    ...analysis.sortedDeterioratingParameters.map((impact) => _buildParameterImpactCard(impact)),
                    const SizedBox(height: 16),
                  ],

                  Text('QUALITY IMPACT BREAKDOWN', style: GoogleFonts.inter(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                  const SizedBox(height: 10),
                  ...analysis.parameterImpacts.values.map((impact) => _buildQualityImpactBar(impact)),
                  const SizedBox(height: 20),

                  Text('NORMAL PARAMETERS', style: GoogleFonts.inter(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                  const SizedBox(height: 10),
                  ...analysis.parameterImpacts.values.where((p) => p.impactPoints == 0).map((p) => _buildNormalParamTile(p)),
                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppConstants.darkSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppConstants.darkCardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.psychology_rounded, color: AppConstants.accentCyan, size: 20),
                            const SizedBox(width: 8),
                            Text('AI ASSESSMENT', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.8)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(analysis.aiSummary, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  if (score < 40)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF3D00)),
                        icon: const Icon(Icons.cleaning_services_rounded),
                        label: const Text('RECORD TANK CLEANING NOW'),
                        onPressed: () {
                          Navigator.pop(context);
                          context.push('/record-cleaning');
                        },
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('CLOSE DETAILS'),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildParameterImpactCard(ParameterImpact impact) {
    Color statusColor = const Color(0xFFFF3D00);
    if (impact.status == 'MODERATE IMPACT') statusColor = const Color(0xFFFFB300);
    if (impact.status == 'LOW IMPACT') statusColor = Colors.orangeAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(impact.name, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(width: 8),
                  Text('${impact.rawValue} ${impact.unit}', style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('${impact.impactPoints} points', style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Text('Status: ', style: TextStyle(color: Colors.white54, fontSize: 11)),
              Text(impact.status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11)),
              const SizedBox(width: 12),
              const Text('Trend: ', style: TextStyle(color: Colors.white54, fontSize: 11)),
              Text(impact.trend, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Reason: "${impact.reason}"', style: const TextStyle(color: Colors.white70, fontSize: 11, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Widget _buildQualityImpactBar(ParameterImpact impact) {
    int deduction = impact.impactPoints.abs();
    double barRatio = (deduction / 35.0).clamp(0.0, 1.0);
    Color barColor = impact.impactPoints == 0 ? Colors.white24 : AppConstants.getScoreColor(100 - deduction * 3);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(impact.name, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
              Text(impact.impactPoints == 0 ? 'No Impact' : '${impact.impactPoints} pts (${impact.status})', style: TextStyle(color: barColor, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: impact.impactPoints == 0 ? 0.05 : barRatio,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNormalParamTile(ParameterImpact impact) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppConstants.darkSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppConstants.darkCardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(impact.name, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Row(
            children: [
              Text('${impact.rawValue} ${impact.unit}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(width: 8),
              const Text('Normal', style: TextStyle(color: Color(0xFF00E676), fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDateFull(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')} ${_getMonthName(d.month)} ${d.year}';
  }

  String _getMonthName(int m) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (m >= 1 && m <= 12) return months[m - 1];
    return '';
  }
}
