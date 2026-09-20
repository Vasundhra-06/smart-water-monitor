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
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')} ${_getMonthName(d.month)} ${d.year}';
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return (month >= 1 && month <= 12) ? months[month - 1] : '';
  }

  Widget _datePickerThemeBuilder(BuildContext context, Widget? child) {
    return Theme(
      data: ThemeData.dark().copyWith(
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
  }

  Future<void> _showCustomDateRangeDialog(BuildContext context) async {
    final now = DateTime.now();
    DateTime tempStart = _customStartDate ?? now.subtract(const Duration(days: 7));
    DateTime tempEnd = _customEndDate ?? now;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final daysCount = tempEnd.difference(tempStart).inDays + 1;

            return Dialog(
              backgroundColor: AppConstants.darkCardBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppConstants.accentCyan.withValues(alpha: 0.4), width: 1.5),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Dialog Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppConstants.accentCyan.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.date_range_rounded, color: AppConstants.accentCyan, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Select Custom Date Range',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                            onPressed: () => Navigator.of(ctx).pop(),
                            splashRadius: 18,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // From & To Date Pickers
                      Row(
                        children: [
                          Expanded(
                            child: _buildDialogDateField(
                              label: 'START DATE (FROM)',
                              dateStr: _formatDate(tempStart),
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: tempStart,
                                  firstDate: now.subtract(const Duration(days: 365)),
                                  lastDate: tempEnd,
                                  builder: _datePickerThemeBuilder,
                                );
                                if (picked != null) {
                                  setDialogState(() {
                                    tempStart = picked;
                                  });
                                }
                              },
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(Icons.arrow_forward_rounded, color: AppConstants.accentCyan, size: 18),
                          ),
                          Expanded(
                            child: _buildDialogDateField(
                              label: 'END DATE (TO)',
                              dateStr: _formatDate(tempEnd),
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: tempEnd,
                                  firstDate: tempStart,
                                  lastDate: now,
                                  builder: _datePickerThemeBuilder,
                                );
                                if (picked != null) {
                                  setDialogState(() {
                                    tempEnd = picked;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Quick Presets
                      const Text(
                        'QUICK SELECT PRESETS',
                        style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          _buildDialogPresetChip('Past 7 Days', () {
                            setDialogState(() {
                              tempStart = now.subtract(const Duration(days: 7));
                              tempEnd = now;
                            });
                          }),
                          _buildDialogPresetChip('Past 14 Days', () {
                            setDialogState(() {
                              tempStart = now.subtract(const Duration(days: 14));
                              tempEnd = now;
                            });
                          }),
                          _buildDialogPresetChip('Past 30 Days', () {
                            setDialogState(() {
                              tempStart = now.subtract(const Duration(days: 30));
                              tempEnd = now;
                            });
                          }),
                          _buildDialogPresetChip('Past 60 Days', () {
                            setDialogState(() {
                              tempStart = now.subtract(const Duration(days: 60));
                              tempEnd = now;
                            });
                          }),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Summary preview info
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppConstants.darkSurface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: AppConstants.accentCyan, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Will display telemetry spanning $daysCount days (${_formatDate(tempStart)} → ${_formatDate(tempEnd)})',
                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Action Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppConstants.accentCyan,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.check, size: 16, color: Colors.black),
                            label: const Text('Apply Range', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                            onPressed: () {
                              setState(() {
                                _customStartDate = tempStart;
                                _customEndDate = tempEnd;
                                _selectedRange = 'custom';
                              });
                              Navigator.of(ctx).pop();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDialogDateField({
    required String label,
    required String dateStr,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppConstants.darkSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppConstants.accentCyan.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.calendar_month_rounded, size: 16, color: AppConstants.accentCyan),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dateStr,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogPresetChip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 10, color: Colors.white70)),
      backgroundColor: AppConstants.darkSurface,
      side: const BorderSide(color: AppConstants.darkCardBorder),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
    );
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
    } else if (_selectedRange == 'custom') {
      final s = _customStartDate ?? now.subtract(const Duration(days: 7));
      final e = _customEndDate ?? now;
      final start = DateTime(s.year, s.month, s.day, 0, 0, 0);
      final end = DateTime(e.year, e.month, e.day, 23, 59, 59);
      final filtered = list.where((r) => !r.timestamp.isBefore(start) && !r.timestamp.isAfter(end)).toList();
      return filtered.isNotEmpty ? filtered : list;
    } else {
      final cutoff = now.subtract(const Duration(days: 30));
      final filtered = list.where((r) => r.timestamp.isAfter(cutoff)).toList();
      return filtered.isNotEmpty ? filtered : list;
    }
  }

  @override
  Widget build(BuildContext context) {
    final readingsAsync = ref.watch(historicalReadingsProvider(widget.tankId));
    final asyncList = readingsAsync.value;
    final rawList = (asyncList != null && asyncList.length > 1)
        ? asyncList
        : MockSensorService.instance.getReadingsForTank(widget.tankId);
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
          // Header Row: Title & Range Selector Buttons
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
                  _buildCustomButton(),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Zone Badges Legend & Scope Indicator (No clutter, neat & clean)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _buildZoneDot(const Color(0xFF00E676), 'Safe (70–100)'),
                  const SizedBox(width: 14),
                  _buildZoneDot(const Color(0xFFFFB300), 'Warning (40–69)'),
                  const SizedBox(width: 14),
                  _buildZoneDot(const Color(0xFFFF3D00), 'Danger (<40)'),
                ],
              ),
              if (_selectedRange == 'custom' && _customStartDate != null && _customEndDate != null)
                InkWell(
                  onTap: () => _showCustomDateRangeDialog(context),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppConstants.accentCyan.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppConstants.accentCyan.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_formatDate(_customStartDate!)} – ${_formatDate(_customEndDate!)} (${readings.length} pts)',
                          style: const TextStyle(color: AppConstants.accentCyan, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 5),
                        const Icon(Icons.edit_calendar_rounded, size: 12, color: AppConstants.accentCyan),
                      ],
                    ),
                  ),
                ),
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
                              ? 'No telemetry data recorded for selected range'
                              : 'No historical telemetry available for this range',
                          style: const TextStyle(color: Colors.white38, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: (spots.length > 1 ? (spots.length - 1).toDouble() : 1.0),
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
                            interval: (readings.length > 8 ? (readings.length / 5).floorToDouble().clamp(1.0, 30.0) : 1.0),
                            getTitlesWidget: (val, meta) {
                              int index = val.toInt();
                              if (index >= 0 && index < readings.length) {
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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

  Widget _buildCustomButton() {
    final isSelected = _selectedRange == 'custom';
    String label = 'Custom';
    if (isSelected && _customStartDate != null && _customEndDate != null) {
      final s = _customStartDate!;
      final e = _customEndDate!;
      label = '${s.day} ${_getMonthName(s.month)} – ${e.day} ${_getMonthName(e.month)}';
    }

    return InkWell(
      onTap: () => _showCustomDateRangeDialog(context),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down,
              size: 14,
              color: isSelected ? Colors.black : Colors.white70,
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
