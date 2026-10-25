import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/period_record.dart';
import '../../core/date_utils.dart';
import '../../core/theme.dart';
import '../../providers/app_data_provider.dart';

/// 统计页：周期规律分析（异常值标红）与经期长度趋势。
class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppDataProvider>();
    final periods = data.periods; // 已按开始日倒序

    return Scaffold(
      appBar: AppBar(title: const Text('统计')),
      body: periods.length < 2
          ? const _EmptyState()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _SummaryCards(data: data),
                const SizedBox(height: 8),
                _CycleChartCard(cycles: _extractCycles(periods)),
                const SizedBox(height: 8),
                _PeriodLengthCard(records: periods.reversed.toList()),
              ],
            ),
    );
  }

  /// 相邻两次经期开始日的间隔（含异常值，标记供图表染色）。
  /// [records] 顺序不限，内部先按开始日升序排列再计算差值。
  static List<({int gap, bool outlier})> _extractCycles(
      List<PeriodRecord> records) {
    final ascending = [...records]
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
    final result = <({int gap, bool outlier})>[];
    for (var i = 1; i < ascending.length; i++) {
      final gap =
          daysBetween(ascending[i - 1].startDate, ascending[i].startDate);
      final outlier = gap < 15 || gap > 60;
      result.add((gap: gap, outlier: outlier));
    }
    return result;
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.insights_outlined,
              size: 56, color: AppColors.textSecondary.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          const Text('记录 2 次经期后，这里会出现周期分析',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.data});

  final AppDataProvider data;

  @override
  Widget build(BuildContext context) {
    final p = data.prediction;
    final avgPeriodLengths = data.logs
        .where((l) => l.flow != null)
        .length; // 简化：打卡天数仅作展示
    return Row(
      children: [
        _StatCard(
          label: '预测周期',
          value: '${p.cycleLength}',
          unit: '天',
          caption: p.quality.label,
        ),
        _StatCard(
          label: '预测经期',
          value: '${p.periodLength}',
          unit: '天',
          caption: '下次 ${p.nextPeriodStart == null ? "—" : "${p.nextPeriodStart!.month}/${p.nextPeriodStart!.day}"}',
        ),
        _StatCard(
          label: '历史样本',
          value: '${p.usedCycleSamples.length}',
          unit: '个周期',
          caption: p.outlierCycles.isEmpty
              ? '$avgPeriodLengths 天打卡'
              : '剔除异常 ${p.outlierCycles.length}',
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.caption,
  });

  final String label;
  final String value;
  final String unit;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(value,
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.tideDeep)),
                  const SizedBox(width: 2),
                  Text(unit,
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textSecondary)),
                ],
              ),
              const SizedBox(height: 4),
              Text(caption,
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 周期长度柱状图：异常周期（<15 或 >60 天）标珊瑚红。
class _CycleChartCard extends StatelessWidget {
  const _CycleChartCard({required this.cycles});

  final List<({int gap, bool outlier})> cycles;

  @override
  Widget build(BuildContext context) {
    final display = cycles.length > 12 ? cycles.sublist(cycles.length - 12) : cycles;
    final maxGap =
        display.map((c) => c.gap).reduce((a, b) => a > b ? a : b).toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('周期长度趋势',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('红柱 = 被算法剔除的异常周期',
                    style: TextStyle(
                        fontSize: 10,
                        color: AppColors.coral.withValues(alpha: 0.9))),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 170,
              child: BarChart(
                BarChartData(
                  maxY: (maxGap + 8).clamp(30, 90),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barTouchData: const BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        getTitlesWidget: (value, meta) => Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '${value.toInt() + 1}',
                            style: const TextStyle(
                                fontSize: 9, color: AppColors.textSecondary),
                          ),
                        ),
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < display.length; i++)
                      BarChartGroupData(x: i, barRods: [
                        BarChartRodData(
                          toY: display[i].gap.toDouble(),
                          width: 14,
                          borderRadius: BorderRadius.circular(4),
                          color: display[i].outlier
                              ? AppColors.coral
                              : AppColors.tide,
                        ),
                      ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 经期持续天数柱状图。
class _PeriodLengthCard extends StatelessWidget {
  const _PeriodLengthCard({required this.records});

  final List<PeriodRecord> records; // 升序

  @override
  Widget build(BuildContext context) {
    final lengths = <int>[];
    for (final r in records) {
      final end = r.endDate;
      if (end == null) continue;
      final len = daysBetween(r.startDate, end) + 1;
      if (len >= 1 && len <= 14) lengths.add(len);
    }
    if (lengths.isEmpty) return const SizedBox.shrink();
    final display = lengths.length > 12 ? lengths.sublist(lengths.length - 12) : lengths;
    final maxLen = display.reduce((a, b) => a > b ? a : b).toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('经期持续天数',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            SizedBox(
              height: 140,
              child: BarChart(
                BarChartData(
                  maxY: maxLen + 2,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barTouchData: const BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        getTitlesWidget: (value, meta) => Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '${value.toInt() + 1}',
                            style: const TextStyle(
                                fontSize: 9, color: AppColors.textSecondary),
                          ),
                        ),
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < display.length; i++)
                      BarChartGroupData(x: i, barRods: [
                        BarChartRodData(
                          toY: display[i].toDouble(),
                          width: 14,
                          borderRadius: BorderRadius.circular(4),
                          color: AppColors.coralSoft,
                        ),
                      ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
