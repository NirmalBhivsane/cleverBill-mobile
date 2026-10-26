import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart' hide Text;

import '../i18n/i18n.dart';

import '../theme/app_theme.dart';
import '../utils/format.dart';

class SalesBarChart extends StatelessWidget {
  const SalesBarChart({
    super.key,
    required this.labels,
    required this.values,
    this.height = 170,
    this.highlightLast = true,
  });
  final List<String> labels;
  final List<double> values;
  final double height;
  final bool highlightLast;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text('No sales data yet', style: TextStyle(color: C.muted)),
        ),
      );
    }
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final top = (maxV <= 0 ? 100 : maxV * 1.25).toDouble();
    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: top,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (g, gi, rod, ri) => BarTooltipItem(
                money(rod.toY),
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: top / 4,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: C.border, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= labels.length) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      labels[i],
                      style: TextStyle(fontSize: 10.5, color: C.muted),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < values.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: values[i],
                    width: values.length > 8 ? 9 : 20,
                    borderRadius: BorderRadius.circular(5),
                    color: (highlightLast && i == values.length - 1)
                        ? C.primary
                        : C.primary.withOpacity(.3),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
