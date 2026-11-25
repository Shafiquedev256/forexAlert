import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../widgets/ui.dart';

({double min, double max}) _range(Iterable<double> values, {bool includeZero = true}) {
  var lo = values.reduce((a, b) => a < b ? a : b);
  var hi = values.reduce((a, b) => a > b ? a : b);
  if (includeZero) {
    if (lo > 0) lo = 0;
    if (hi < 0) hi = 0;
  }
  final pad = ((hi - lo).abs() * 0.12).clamp(0.5, double.infinity).toDouble();
  return (min: lo - pad, max: hi + pad);
}

Widget _leftTitle(double value, TitleMeta meta, String suffix) =>
    Text('${value.toStringAsFixed(1)}$suffix', style: const TextStyle(fontSize: 10));

const _hidden = AxisTitles(sideTitles: SideTitles(showTitles: false));

/// A single line over time (equity curve, rolling expectancy, win rate).
class LineSeriesChart extends StatelessWidget {
  const LineSeriesChart({super.key, required this.values, this.color, this.suffix = '', this.height = 200});

  final List<double> values;
  final Color? color;
  final String suffix;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    final c = color ?? Theme.of(context).colorScheme.primary;
    final r = _range(values);
    final interval = ((r.max - r.min) / 4).clamp(0.1, double.infinity).toDouble();
    final spots = [for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i])];

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: r.min,
          maxY: r.max,
          minX: 0,
          maxX: values.length < 2 ? 1 : (values.length - 1).toDouble(),
          gridData: FlGridData(drawVerticalLine: false, horizontalInterval: interval),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: _hidden,
            rightTitles: _hidden,
            bottomTitles: _hidden,
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                interval: interval,
                getTitlesWidget: (v, meta) => _leftTitle(v, meta, suffix),
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              color: c,
              barWidth: 2.5,
              isCurved: false,
              dotData: FlDotData(show: values.length < 3),
              belowBarData: BarAreaData(show: true, color: c.withValues(alpha: 0.12)),
            ),
          ],
        ),
      ),
    );
  }
}

class BarDatum {
  const BarDatum(this.label, this.value, {this.faded = false});

  final String label;
  final double value;

  /// Draw lighter (used for low-sample segments).
  final bool faded;
}

/// Bars that go up (gain) or down (loss), scrollable sideways when crowded.
class SignedBarsChart extends StatelessWidget {
  const SignedBarsChart({super.key, required this.data, this.height = 200, this.suffix = ''});

  final List<BarDatum> data;
  final double height;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final r = _range(data.map((d) => d.value));
    final interval = ((r.max - r.min) / 4).clamp(0.1, double.infinity).toDouble();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (data.length * 46.0).clamp(constraints.maxWidth, double.infinity).toDouble();
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            height: height,
            child: BarChart(
              BarChartData(
                minY: r.min,
                maxY: r.max,
                alignment: BarChartAlignment.spaceAround,
                gridData: FlGridData(drawVerticalLine: false, horizontalInterval: interval),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: _hidden,
                  rightTitles: _hidden,
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      interval: interval,
                      getTitlesWidget: (v, meta) => _leftTitle(v, meta, suffix),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (v, meta) {
                        final i = v.toInt();
                        if (i < 0 || i >= data.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(data[i].label, style: const TextStyle(fontSize: 9), overflow: TextOverflow.clip),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < data.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: data[i].value,
                          width: 16,
                          borderRadius: BorderRadius.circular(4),
                          color: (data[i].value >= 0 ? kGain : kLoss).withValues(alpha: data[i].faded ? 0.35 : 1),
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
  }
}
