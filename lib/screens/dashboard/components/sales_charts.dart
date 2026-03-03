import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../core/theme_service.dart';

class DashboardSalesCharts extends ConsumerWidget {
  const DashboardSalesCharts({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardProvider);
    final hasData = state.salesSpots.isNotEmpty || state.purchaseSpots.isNotEmpty;
    final rangeLabel = state.selectedDateRange == 'today'
        ? 'Today'
        : state.selectedDateRange == 'yesterday'
        ? 'Yesterday'
        : state.selectedDateRange == '7days'
        ? 'Last 7 Days'
        : state.selectedDateRange == '30days'
        ? 'Last 30 Days'
        : 'This Month';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Financial Performance",
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "$rangeLabel Analytics",
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: context.textSecondary.withValues(alpha: 0.4),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _chartLegendItem(context, "Revenue", const Color(0xFF3B82F6)),
                      const SizedBox(width: 16),
                      _chartLegendItem(context, "Expenses", const Color(0xFFF59E0B)),
                      const SizedBox(width: 16),
                      _chartLegendItem(context, "Net Flow", const Color(0xFF10B981)),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 280,
            child: !hasData
                ? Center(
                    child: Text(
                      "No data for this period",
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        color: context.textSecondary,
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: LineChart(
                      LineChartData(
                        clipData: const FlClipData.all(),
                        minX: 0,
                        maxX: state.chartXLabels.isEmpty
                            ? 0
                            : (state.chartXLabels.length - 1).toDouble(),
                        minY: 0,
                        lineTouchData: LineTouchData(
                          getTouchedSpotIndicator:
                              (LineChartBarData barData, List<int> spotIndexes) {
                            return spotIndexes.map((spotIndex) {
                              return TouchedSpotIndicatorData(
                                FlLine(
                                  color: barData.color?.withValues(alpha: 0.1),
                                  strokeWidth: 2,
                                  dashArray: [5, 5],
                                ),
                                FlDotData(
                                  getDotPainter: (spot, percent, barData, index) =>
                                      FlDotCirclePainter(
                                    radius: 6,
                                    color: Colors.white,
                                    strokeWidth: 3,
                                    strokeColor: barData.color ?? Colors.blue,
                                  ),
                                ),
                              );
                            }).toList();
                          },
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipColor: (touchedSpot) => context.cardBg.withValues(alpha: 0.98),
                            tooltipPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            tooltipBorder: BorderSide(
                              color: context.borderColor.withValues(alpha: 0.5),
                            ),
                            getTooltipItems: (touchedSpots) {
                              return touchedSpots.map((spot) {
                                final seriesName = spot.barIndex == 0
                                    ? "Revenue (Incl. Tax)"
                                    : spot.barIndex == 1
                                    ? "Expenses (Purchase)"
                                    : "Net Flow (Profit)";
                                return LineTooltipItem(
                                  "${seriesName}\n",
                                  TextStyle(
                                    fontFamily: 'Outfit',
                                    color: context.textSecondary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: "₹${NumberFormat('#,###.##').format(spot.y)}",
                                      style: TextStyle(
                                        fontFamily: 'Outfit',
                                        color: spot.bar.color,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                );
                              }).toList();
                            },
                          ),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: context.dividerColor.withValues(alpha: 0.05),
                            strokeWidth: 1,
                          ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              interval: 1,
                              getTitlesWidget: (value, meta) {
                                int idx = value.toInt();
                                if (idx < 0 || idx >= state.chartXLabels.length) return const SizedBox();
                                if (state.selectedDateRange == 'today' && idx % 2 != 0) return const SizedBox();
                                return Padding(
                                  padding: const EdgeInsets.only(top: 10.0),
                                  child: Text(
                                    state.chartXLabels[idx],
                                    style: TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 9,
                                      color: context.textSecondary.withValues(alpha: 0.3),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 64,
                              getTitlesWidget: (value, meta) {
                                if (value == 0) return const SizedBox();
                                String formatted = value >= 1000
                                    ? '₹${(value / 1000).toStringAsFixed(0)}k'
                                    : '₹${value.toInt()}';
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: Text(
                                    formatted,
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 9,
                                      color: context.textSecondary.withValues(alpha: 0.3),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          _buildLineBarData(state.salesSpots, const Color(0xFF3B82F6)),
                          _buildLineBarData(state.purchaseSpots, const Color(0xFFF59E0B)),
                          _buildLineBarData(state.profitSpots, const Color(0xFF10B981)),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chartLegendItem(BuildContext context, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 4),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: context.textSecondary.withValues(alpha: 0.6),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  LineChartBarData _buildLineBarData(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots.isEmpty ? [const FlSpot(0, 0)] : spots,
      isCurved: true,
      curveSmoothness: 0.35,
      color: color,
      barWidth: 3,
      isStrokeCapRound: true,
      isStrokeJoinRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );
  }
}
