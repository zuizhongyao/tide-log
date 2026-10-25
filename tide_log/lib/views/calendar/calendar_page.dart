import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../algorithms/period_calculator.dart';
import '../../core/date_utils.dart';
import '../../core/theme.dart';
import '../../models/tags.dart';
import '../../providers/app_data_provider.dart';
import '../home/countdown_ring.dart' show CnDateFormatter;
import '../widgets/add_period_dialog.dart';

/// 日历页：标注 经期/预测经期/排卵日/易孕期/安全期 的月历视图。
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _displayedMonth;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _displayedMonth = DateTime(now.year, now.month, 1);
  }

  void _shiftMonth(int delta) {
    setState(() {
      _displayedMonth =
          DateTime(_displayedMonth.year, _displayedMonth.month + delta, 1);
      _selectedDay = null;
    });
  }

  /// 周一为一周起点 的首日偏移。
  int _weekdayOffset(DateTime first) => (first.weekday - 1) % 7;

  Color _phaseBackground(CyclePhase phase) => switch (phase) {
        CyclePhase.menstruation => AppColors.coral,
        CyclePhase.predictedMenstruation => AppColors.coralSoft,
        CyclePhase.ovulationDay => AppColors.ovulation,
        CyclePhase.fertile => AppColors.fertile.withValues(alpha: 0.55),
        CyclePhase.safe => Colors.transparent,
      };

  Color _phaseForeground(CyclePhase phase) => switch (phase) {
        CyclePhase.menstruation || CyclePhase.ovulationDay => Colors.white,
        _ => AppColors.textPrimary,
      };

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppDataProvider>();
    final today = normalizeDate(DateTime.now());
    final days = daysInMonth(_displayedMonth.year, _displayedMonth.month);
    final offset = _weekdayOffset(_displayedMonth);

    return Scaffold(
      appBar: AppBar(title: const Text('日历')),
      body: Column(
        children: [
          // ---- 月份切换 ----
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                  onPressed: () => _shiftMonth(-1),
                  icon: const Icon(Icons.chevron_left)),
              const SizedBox(width: 8),
              Text(CnDateFormatter.month(_displayedMonth),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              IconButton(
                  onPressed: () => _shiftMonth(1),
                  icon: const Icon(Icons.chevron_right)),
            ],
          ),
          // ---- 星期表头 ----
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: ['一', '二', '三', '四', '五', '六', '日']
                  .map((w) => Expanded(
                        child: Center(
                          child: Text(w,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                        ),
                      ))
                  .toList(),
            ),
          ),
          // ---- 日期网格 ----
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 0.92,
              ),
              itemCount: offset + days,
              itemBuilder: (context, index) {
                if (index < offset) return const SizedBox.shrink();
                final day = DateTime(_displayedMonth.year,
                    _displayedMonth.month, index - offset + 1);
                return _DayCell(
                  day: day,
                  phase: data.prediction.phaseOn(day),
                  isToday: isSameDay(day, today),
                  hasLog: data.logOn(day)?.hasAnyEntry ?? false,
                  background: _phaseBackground,
                  foreground: _phaseForeground,
                  isSelected:
                      _selectedDay != null && isSameDay(day, _selectedDay!),
                  onTap: () => setState(() => _selectedDay = day),
                );
              },
            ),
          ),
          // ---- 图例 ----
          const _Legend(),
          // ---- 选中日详情 ----
          if (_selectedDay != null)
            _DayDetailCard(day: _selectedDay!),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.phase,
    required this.isToday,
    required this.hasLog,
    required this.isSelected,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final DateTime day;
  final CyclePhase phase;
  final bool isToday;
  final bool hasLog;
  final bool isSelected;
  final Color Function(CyclePhase) background;
  final Color Function(CyclePhase) foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = background(phase);
    final fg = foreground(phase);
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected
                  ? AppColors.tideDeep
                  : isToday
                      ? AppColors.tide
                      : Colors.transparent,
              width: isToday ? 2 : 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${day.day}',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                      color: fg)),
              const SizedBox(height: 2),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasLog
                      ? (bg == Colors.transparent
                          ? AppColors.tide
                          : Colors.white.withValues(alpha: 0.9))
                      : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    const items = [
      (AppColors.coral, '经期'),
      (AppColors.coralSoft, '预测经期'),
      (AppColors.ovulation, '排卵日'),
      (AppColors.fertile, '易孕期'),
      (AppColors.tide, '有打卡'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          for (final (color, label) in items)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color == AppColors.tide
                          ? Colors.transparent
                          : color,
                      border: Border.all(color: color, width: 1.4)),
                ),
                const SizedBox(width: 4),
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
        ],
      ),
    );
  }
}

class _DayDetailCard extends StatelessWidget {
  const _DayDetailCard({required this.day});

  final DateTime day;

  Future<void> _run(BuildContext context, Future<String?> action) async {
    final error = await action;
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final data = context.read<AppDataProvider>();
    final covering = data.periods.where((r) => r.covers(day)).toList();
    if (covering.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除经期记录'),
        content: Text(
            '将删除 ${CnDateFormatter.full(covering.first.startDate)} 开始的一段经期记录。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('删除')),
        ],
      ),
    );
    if (confirmed == true) await data.deletePeriod(covering.first.id);
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppDataProvider>();
    final log = data.logOn(day);
    final phase = data.prediction.phaseOn(day);
    final cycleDay = data.prediction.cycleDayOn(day);
    final today = normalizeDate(DateTime.now());
    final isPastDay = !day.isAfter(today);
    final ongoing = data.ongoingPeriod;
    final covering = data.periods.where((r) => r.covers(day)).toList();

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  CnDateFormatter.full(day),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  cycleDay == null ? phase.label : '${phase.label} · 第 $cycleDay 天',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (log == null || !log.hasAnyEntry)
              const Text('当日无打卡记录',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary))
            else ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (log.flow != null) _detailChip('经量 ${log.flow!.label}'),
                  if (log.pain != null) _detailChip('痛经 ${log.pain!.label}'),
                  for (final c in log.moodCodes)
                    _detailChip(MoodTags.labelOf(c)),
                  for (final c in log.symptomCodes)
                    _detailChip(SymptomTags.labelOf(c)),
                  if (log.intercourse) _detailChip('同房'),
                ],
              ),
              if (log.notes != null && log.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(log.notes!,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ],
            // 历史补录操作区（仅过去的日期显示）
            if (isPastDay) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (covering.isEmpty)
                    ActionChip(
                      avatar: const Icon(Icons.play_arrow_rounded, size: 16),
                      label: const Text('这天开始经期'),
                      onPressed: () => _run(context,
                          context.read<AppDataProvider>().markPeriodStart(day)),
                    ),
                  if (ongoing != null && !day.isBefore(ongoing.startDate))
                    ActionChip(
                      avatar: const Icon(Icons.stop_rounded, size: 16),
                      label: const Text('在这天结束经期'),
                      onPressed: () => _run(context,
                          context.read<AppDataProvider>().markPeriodEnd(day)),
                    ),
                  if (covering.isEmpty)
                    ActionChip(
                      avatar: const Icon(Icons.history_edu, size: 16),
                      label: const Text('补录整段经期…'),
                      onPressed: () => showAddPeriodDialog(context),
                    ),
                  if (covering.isNotEmpty)
                    ActionChip(
                      avatar: const Icon(Icons.delete_outline,
                          size: 16, color: AppColors.danger),
                      label: const Text('删除该经期',
                          style: TextStyle(color: AppColors.danger)),
                      onPressed: () => _confirmDelete(context),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailChip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.tideMist,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label,
            style:
                const TextStyle(fontSize: 11, color: AppColors.textPrimary)),
      );
}
