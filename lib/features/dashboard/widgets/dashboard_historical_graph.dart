import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/mock_sensor_service.dart';
import '../../../data/models/sensor_reading.dart';

class DashboardHistoricalGraph extends ConsumerStatefulWidget {
  final String tankId;

  const DashboardHistoricalGraph({
    super.key,
    required this.tankId,
  });

  @override
  ConsumerState<DashboardHistoricalGraph> createState() => _DashboardHistoricalGraphState();
}

class _DashboardHistoricalGraphState extends ConsumerState<DashboardHistoricalGraph> {
  String _selectedRange = '30d'; // 'today', '7d', '30d', 'custom'
  DateTimeRange? _customDateRange;

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 1)),
      initialDateRange: _customDateRange ?? DateTimeRange(
        start: now.subtract(const Duration(days: 14)),
        end: now,
      ),
      helpText: 'SELECT CUSTOM DATE RANGE',
      cancelText: 'CANCEL',
      confirmText: 'APPLY',
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: AppConstants.darkBackground,
            colorScheme: const ColorScheme.dark(
              primary: AppConstants.accentCyan,
              onPrimary: Colors.black,
              surface: AppConstants.darkCardBackground,
              onSurface: Colors.white,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: AppConstants.darkBackground,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _selectedRange = 'custom';
      });
    }
  }

  List<SensorReading> _filterReadings(List<SensorReading> list) {
    if (list.isEmpty) return [];
    final now = DateTime.now();

    if (_selectedRange == 'today') {
      final todayList = list.where((r) =>
        r.timestamp.day == now.day &&
        r.timestamp.month == now.month &&
        r.timestamp.year == now.year
      ).toList();
      return todayList.isNotEmpty ? todayList : list.take(6).toList();
    } else if (_selectedRange == '7d') {
      final cutoff = now.subtract(const Duration(days: 7));
      final filtered = list.where((r) => r.timestamp.isAfter(cutoff)).toList();
      return filtered.isNotEmpty ? filtered : list.take(14).toList();
    } else if (_selectedRange == 'custom' && _customDateRange != null) {
      final start = DateTime(_customDateRange!.start.year, _customDateRange!.start.month, _customDateRange!.start.day, 0, 0, 0);
      final end = DateTime(_customDateRange!.end.year, _customDateRange!.end.month, _customDateRange!.end.day, 23, 59, 59);
      final filtered = list.where((r) => !r.timestamp.isBefore(start) && !r.timestamp.isAfter(end)).toList();
      return filtered;
    } else {
      final cutoff = now.subtract(const Duration(days: 30));
      final filtered = list.where((r) => r.timestamp.isAfter(cutoff)).toList();
      return filtered.isNotEmpty ? filtered : list;
    }
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return (month >= 1 && month <= 12) ? months[month - 1] : '';
  }

  @override
  Widget build(BuildContext context) {
    final readingsAsync = ref.watch(historicalReadingsProvider(widget.tankId));
    final rawList = readingsAsync.value ?? MockSensorService.instance.getReadingsForTank(widget.tankId);
    final readings = _filterReadings(rawList);

    double sumScore = 0;
    int minScore = 100;
    for (var r in readings) {
      final s = r.waterQualityScore;
      if (s < minScore) minScore = s;
      sumScore += s;
    }
    final avgScore = readings.isNotEmpty ? (sumScore / readings.length).round() : 85;

    final spots = <FlSpot>[];
    for (int i = 0; i < readings.length; i++) {
      spots.add(FlSpot(i.toDouble(), readings[i].waterQualityScore.toDouble()));
    }
    if (spots.length == 1) {
      spots.add(FlSpot(1, spots[0].y));
    }

    final latestScore = readings.isNotEmpty ? readings.last.waterQualityScore : 85;
    final lineGradientColor = AppConstants.getScoreColor(latestScore);

    return Container(
      decoration: BoxDecoration(
        color: AppConstants.darkCardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppConstants.darkCardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Title & Range Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppConstants.accentCyan.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.show_chart_rounded, color: AppConstants.accentCyan, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'HISTORICAL WATER QUALITY TREND',
                    style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                  ),
                ],
              ),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                alignment: WrapAlignment.end,
                children: [
                  _buildRangeButton('Today', 'today'),
                  _buildRangeButton('7 Days', '7d'),
                  _buildRangeButton('30 Days', '30d'),
                  _buildCustomRangeButton(),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Zone Badges Legend
          Row(
            children: [
              _buildZoneDot(const Color(0xFF00E676), 'Safe (70–100)'),
              const SizedBox(width: 14),
              _buildZoneDot(const Color(0xFFFFB300), 'Warning (40–69)'),
              const SizedBox(width: 14),
              _buildZoneDot(const Color(0xFFFF3D00), 'Danger (<40)'),
            ],
          ),
          const SizedBox(height: 16),

          // Main Chart
          SizedBox(
            height: 240,
            child: readings.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.event_busy_rounded, color: Colors.white24, size: 36),
                        const SizedBox(height: 8),
                        Text(
                          _selectedRange == 'custom'
                              ? 'No telemetry data recorded within selected date range'
                              : 'No historical telemetry available',
                          style: const TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: 100,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (val) => FlLine(
                          color: Colors.white.withValues(alpha: 0.05),
                          strokeWidth: 1,
                        ),
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
                                return Text('${val.toInt()}', style: TextStyle(color: tc, fontSize: 9, fontWeight: FontWeight.bold));
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
                              if (index >= 0 && index < readings.length && (index % (readings.length > 8 ? 4 : 2) == 0)) {
                                final d = readings[index].timestamp;
                                return Text('${d.day} ${_getMonthName(d.month)}', style: const TextStyle(color: Colors.white38, fontSize: 9));
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
                            color: const Color(0xFF00E676).withValues(alpha: 0.4),
                            strokeWidth: 1,
                            dashArray: [5, 5],
                          ),
                          HorizontalLine(
                            y: 40,
                            color: const Color(0xFFFF3D00).withValues(alpha: 0.5),
                            strokeWidth: 1,
                            dashArray: [5, 5],
                          ),
                        ],
                      ),
                      lineTouchData: LineTouchData(
                        enabled: true,
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              int idx = spot.x.toInt();
                              if (idx >= 0 && idx < readings.length) {
                                final r = readings[idx];
                                return LineTooltipItem(
                                  '${r.timestamp.day} ${_getMonthName(r.timestamp.month)} • Score: ${r.waterQualityScore}/100\npH: ${r.ph} | Turb: ${r.turbidity.toStringAsFixed(1)} | TDS: ${r.tds.toInt()}',
                                  TextStyle(
                                    color: AppConstants.getScoreColor(r.waterQualityScore),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
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
                          barWidth: 2.5,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              if (index >= 0 && index < readings.length) {
                                final s = readings[index].waterQualityScore;
                                return FlDotCirclePainter(
                                  radius: s < 40 ? 4.5 : 3.0,
                                  color: AppConstants.getScoreColor(s),
                                  strokeWidth: 1.5,
                                  strokeColor: Colors.white,
                                );
                              }
                              return FlDotCirclePainter(radius: 3, color: AppConstants.accentCyan);
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                lineGradientColor.withValues(alpha: 0.2),
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
          const SizedBox(height: 12),

          // Mini metrics bar below graph
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppConstants.darkSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppConstants.darkCardBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryStat('Average Quality', '$avgScore / 100', AppConstants.getScoreColor(avgScore)),
                Container(width: 1, height: 20, color: AppConstants.darkCardBorder),
                _buildSummaryStat('Lowest Recorded', '$minScore / 100', AppConstants.getScoreColor(minScore)),
                Container(width: 1, height: 20, color: AppConstants.darkCardBorder),
                _buildSummaryStat('Trend Direction', avgScore >= 75 ? 'Optimal Stable' : (avgScore >= 50 ? 'Moderate' : 'Deteriorating'), avgScore >= 75 ? const Color(0xFF00E676) : const Color(0xFFFFB300)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRangeButton(String label, String value) {
    final isSelected = _selectedRange == value;
    return InkWell(
      onTap: () => setState(() => _selectedRange = value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppConstants.accentCyan : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? AppConstants.accentCyan : AppConstants.darkCardBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildCustomRangeButton() {
    final isSelected = _selectedRange == 'custom';
    String label = 'Custom';
    if (isSelected && _customDateRange != null) {
      final s = _customDateRange!.start;
      final e = _customDateRange!.end;
      label = '${s.day} ${_getMonthName(s.month)} - ${e.day} ${_getMonthName(e.month)}';
    }

    return InkWell(
      onTap: _pickCustomRange,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppConstants.accentCyan : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? AppConstants.accentCyan : AppConstants.darkCardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.date_range_rounded,
              size: 11,
              color: isSelected ? Colors.black : Colors.white70,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white70,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoneDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildSummaryStat(String title, String val, Color valColor) {
    return Row(
      children: [
        Text('$title: ', style: const TextStyle(color: Colors.white54, fontSize: 11)),
        Text(val, style: TextStyle(color: valColor, fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
