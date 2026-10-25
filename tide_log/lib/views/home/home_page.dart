import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../algorithms/period_calculator.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../widgets/debug_panel_action.dart';
import '../../models/daily_log.dart';
import '../../models/tags.dart';
import '../../providers/app_data_provider.dart';
import 'countdown_ring.dart';

/// 主页：倒计时圆环 + 快捷多维打卡面板 + 云端同步状态。
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: const [DebugPanelAction(), SizedBox(width: 4)],
      ),
      body: Consumer<AppDataProvider>(
        builder: (context, data, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Center(
                child: CountdownRing(
                  prediction: data.prediction,
                  today: today,
                ),
              ),
              const SizedBox(height: 12),
              _PhaseAndSyncRow(data: data, today: today),
              const SizedBox(height: 16),
              QuickLogPanel(day: today),
            ],
          );
        },
      ),
    );
  }
}

class _PhaseAndSyncRow extends StatelessWidget {
  const _PhaseAndSyncRow({required this.data, required this.today});

  final AppDataProvider data;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final phase = data.prediction.phaseOn(today);
    final cycleDay = data.prediction.cycleDayOn(today);
    final unsynced = data.hasUnsyncedChanges;
    final configured = data.lastSyncedAt != null;

    final Color phaseColor;
    switch (phase) {
      case CyclePhase.menstruation:
      case CyclePhase.predictedMenstruation:
        phaseColor = AppColors.coral;
      case CyclePhase.ovulationDay:
        phaseColor = AppColors.ovulation;
      case CyclePhase.fertile:
        phaseColor = AppColors.fertile;
      case CyclePhase.safe:
        phaseColor = AppColors.safe;
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: phaseColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            cycleDay == null
                ? phase.label
                : '${phase.label} · 周期第 $cycleDay 天',
            style: TextStyle(
                fontSize: 12, color: phaseColor, fontWeight: FontWeight.w600),
          ),
        ),
        const Spacer(),
        Icon(
          unsynced
              ? Icons.cloud_upload_outlined
              : configured
                  ? Icons.cloud_done_outlined
                  : Icons.cloud_off_outlined,
          size: 15,
          color: unsynced ? AppColors.coral : AppColors.textSecondary,
        ),
        const SizedBox(width: 4),
        Text(
          unsynced ? '有本地变更待同步' : (configured ? '已与云端同步' : '未配置云端同步'),
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

/// 快捷多维打卡面板（美柚维度：经量/痛经/情绪/症状/同房/经期起止）。
class QuickLogPanel extends StatelessWidget {
  const QuickLogPanel({super.key, required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppDataProvider>();
    final log = data.logOn(day);
    final hasOngoing = data.ongoingPeriod != null;
    final isPeriodDay = data.periodCovers(day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---- 经期起止控制 ----
        _SectionCard(
          title: '经期',
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isPeriodDay
                      ? null
                      : () => context
                          .read<AppDataProvider>()
                          .markPeriodStart(day),
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  label: const Text('经期开始'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.coral,
                    side: const BorderSide(color: AppColors.coralSoft),
                    disabledForegroundColor: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: hasOngoing
                      ? () => context.read<AppDataProvider>().markPeriodEnd(day)
                      : null,
                  icon: const Icon(Icons.stop_rounded, size: 20),
                  label: const Text('经期结束'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.tideDeep,
                    side: const BorderSide(color: AppColors.tideLight),
                    disabledForegroundColor: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        // ---- 经量 ----
        _SectionCard(
          title: '经量',
          selectedHint: log?.flow?.label,
          child: Row(
            children: FlowLevel.values
                .map((level) => Expanded(
                      child: _ChoiceCell(
                        label: level.label,
                        selected: log?.flow == level,
                        color: AppColors.coral,
                        onTap: () =>
                            context.read<AppDataProvider>().setFlow(day, level),
                      ),
                    ))
                .toList(),
          ),
        ),
        // ---- 痛经 ----
        _SectionCard(
          title: '痛经',
          selectedHint: log?.pain?.label,
          child: Row(
            children: PainLevel.values
                .map((level) => Expanded(
                      child: _ChoiceCell(
                        label: level.label,
                        selected: log?.pain == level,
                        color: AppColors.coralDeep,
                        onTap: () =>
                            context.read<AppDataProvider>().setPain(day, level),
                      ),
                    ))
                .toList(),
          ),
        ),
        // ---- 情绪 ----
        _SectionCard(
          title: '情绪',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < MoodTags.labels.length; i++)
                _TagChip(
                  label: MoodTags.labels[i],
                  selected: log?.moodCodes.contains(i) ?? false,
                  onTap: () => context
                      .read<AppDataProvider>()
                      .toggleMood(day, i),
                ),
            ],
          ),
        ),
        // ---- 身体症状 ----
        _SectionCard(
          title: '身体症状',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < SymptomTags.labels.length; i++)
                _TagChip(
                  label: SymptomTags.labels[i],
                  selected: log?.symptomCodes.contains(i) ?? false,
                  onTap: () => context
                      .read<AppDataProvider>()
                      .toggleSymptom(day, i),
                ),
            ],
          ),
        ),
        // ---- 同房 ----
        _SectionCard(
          title: '同房记录',
          child: Row(
            children: [
              Icon(
                log?.intercourse ?? false
                    ? Icons.favorite
                    : Icons.favorite_border,
                size: 20,
                color: log?.intercourse ?? false
                    ? AppColors.coral
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                (log?.intercourse ?? false) ? '当日有记录' : '未记录',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
              const Spacer(),
              Switch(
                value: log?.intercourse ?? false,
                activeThumbColor: AppColors.coral,
                onChanged: (v) =>
                    context.read<AppDataProvider>().setIntercourse(day, v),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.selectedHint,
  });

  final String title;
  final Widget child;
  final String? selectedHint;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                if (selectedHint != null) ...[
                  const SizedBox(width: 8),
                  Text('已选：$selectedHint',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ],
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// 单选格子（经量/痛经）。
class _ChoiceCell extends StatelessWidget {
  const _ChoiceCell({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? color : AppColors.tideMist,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// 多选标签。
class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.tide : AppColors.tideMist,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? Colors.white : AppColors.textPrimary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
