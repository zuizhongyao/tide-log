import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../algorithms/period_calculator.dart';
import '../../core/date_utils.dart';
import '../../core/theme.dart';
import '../../models/daily_log.dart';
import '../../models/period_record.dart';
import '../../models/tags.dart';
import '../../services/database_service.dart';
import 'oss_debug_page.dart';

/// 仅 debug 构建可达：数据库调试面板。
///
/// 供开发期手动验证数据层（第二步），后续步骤排查数据问题时也可复用。
/// 正式版不包含本页面的任何入口，也不包含指向本页的导航代码。
class DbDebugPage extends StatefulWidget {
  const DbDebugPage({super.key});

  @override
  State<DbDebugPage> createState() => _DbDebugPageState();
}

class _DbDebugPageState extends State<DbDebugPage> {
  final List<String> _logs = [];
  final DateFormat _timeFmt = DateFormat('HH:mm:ss.SSS');

  void _log(String message) {
    setState(() {
      _logs.add('[${_timeFmt.format(DateTime.now())}] $message');
    });
  }

  void _openOssPanel() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OssDebugPage()),
    );
  }

  Future<void> _run(String title, Future<String> Function() action) async {
    _log('▶ $title …');
    try {
      final result = await action();
      _log('✓ $title：$result');
    } catch (e) {
      _log('✗ $title 异常：$e');
    }
  }

  Future<String> _writeSampleLog() async {
    final today = DateTime.now();
    await DatabaseService.instance.dailyLogs.save(DailyLog.forDate(today)
      ..flow = FlowLevel.moderate
      ..pain = PainLevel.mild
      ..moodCodes = [0, 1]
      ..symptomCodes = [0, 2]
      ..intercourse = true
      ..notes = '调试面板写入的示例数据');
    return '已写入今日打卡';
  }

  Future<String> _readTodayLog() async {
    final log = DatabaseService.instance.dailyLogs
        .getByDateSync(DateTime.now());
    if (log == null) return '今日无打卡记录';
    return 'id=${log.id}，经量=${log.flow?.label ?? "未记录"}，'
        '痛经=${log.pain?.label ?? "未记录"}，'
        '情绪=[${log.moodCodes.map(MoodTags.labelOf).join("、")}]，'
        '症状=[${log.symptomCodes.map(SymptomTags.labelOf).join("、")}]，'
        '同房=${log.intercourse ? "是" : "否"}，备注=${log.notes ?? "无"}，'
        'updatedAt=${_timeFmt.format(log.updatedAt)}';
  }

  Future<String> _createOngoingPeriod() async {
    final record = await DatabaseService.instance.periodRecords
        .save(PeriodRecord.create(DateTime.now()));
    return '经期 id=${record.id}，从今天开始（进行中）';
  }

  Future<String> _createHistoryPeriod() async {
    final now = DateTime.now();
    final record = await DatabaseService.instance.periodRecords.save(
        PeriodRecord.create(addDays(now, -5), end: addDays(now, -2)));
    return '历史经期 id=${record.id}，'
        '${DateFormat("MM-dd").format(record.startDate)} ~ '
        '${DateFormat("MM-dd").format(record.endDate!)}';
  }

  Future<String> _listPeriods() async {
    final all = DatabaseService.instance.periodRecords.getAllSync();
    if (all.isEmpty) return '无经期记录';
    return all
        .map((r) => 'id=${r.id} '
            '${DateFormat("MM-dd").format(r.startDate)}~'
            '${r.endDate == null ? "进行中" : DateFormat("MM-dd").format(r.endDate!)}'
            '（${r.source.label}）')
        .join('；');
  }

  Future<String> _showSyncMeta() async {
    final meta = DatabaseService.instance.syncMeta.getSync();
    return 'lastLocalChangeAt='
        '${meta.lastLocalChangeAt == null ? "无" : _timeFmt.format(meta.lastLocalChangeAt!)}，'
        'lastSyncedAt=${meta.lastSyncedAt == null ? "无" : _timeFmt.format(meta.lastSyncedAt!)}，'
        'remoteStamp=${meta.lastRemoteStamp ?? "无"}';
  }

  /// 生成 4 个历史经期（间隔 28 天，每次持续 5 天），供预测算法演示。
  Future<String> _seedDemoHistory() async {
    final db = DatabaseService.instance;
    final today = DateTime.now();
    for (final offsetDays in [-112, -84, -56, -28]) {
      final start = addDays(today, offsetDays);
      await db.periodRecords
          .save(PeriodRecord.create(start, end: addDays(start, 4)));
    }
    return '已生成 4 条历史经期（PeriodRecord 共 ${db.periodRecords.countSync()} 条），'
        '可点击「经期预测结果」查看 WMA 推算';
  }

  /// 运行 PeriodCalculator 并输出人类可读的预测摘要。
  Future<String> _runPredict() async {
    final db = DatabaseService.instance;
    final records = db.periodRecords.getAllSync();
    final p = PeriodCalculator.predict(records: records);
    final day = DateFormat('MM-dd').format;
    return '质量=${p.quality.label}，周期=${p.cycleLength}天'
        '(WMA=${p.rawCycleLength.toStringAsFixed(2)})，经期=${p.periodLength}天；'
        '下次经期=${p.nextPeriodStart == null ? "无锚点" : day(p.nextPeriodStart!)}，'
        '排卵日=${p.ovulationDate == null ? "无" : day(p.ovulationDate!)}，'
        '易孕=${p.fertileWindowStart == null ? "无" : "${day(p.fertileWindowStart!)}~${day(p.fertileWindowEnd!)}"}，'
        '今日=${p.phaseOn(DateTime.now()).label}（周期第${p.cycleDayOn(DateTime.now()) ?? "?"}天）；'
        '样本=${p.usedCycleSamples}，剔除异常=${p.outlierCycles.isEmpty ? "无" : p.outlierCycles}';
  }

  Future<String> _deleteTodayLog() async {
    final ok = await DatabaseService.instance.dailyLogs
        .deleteByDate(DateTime.now());
    return ok ? '已删除今日打卡' : '今日本来就没有打卡';
  }

  Future<String> _wipeAll() async {
    final db = DatabaseService.instance;
    for (final log in db.dailyLogs.getAllSync()) {
      await db.dailyLogs.deleteByDate(log.date);
    }
    for (final record in db.periodRecords.getAllSync().toList()) {
      await db.periodRecords.delete(record.id);
    }
    return '已清空全部业务数据（DailyLog=${db.dailyLogs.countSync()}，'
        'PeriodRecord=${db.periodRecords.countSync()}）';
  }

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('数据库调试面板')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ActionChip('写入示例打卡（今天）', () => _run('写入示例打卡', _writeSampleLog)),
                _ActionChip('查询今日打卡', () => _run('查询今日打卡', _readTodayLog)),
                _ActionChip('删除今日打卡', () => _run('删除今日打卡', _deleteTodayLog)),
                _ActionChip('创建经期（今天开始·进行中）',
                    () => _run('创建进行中经期', _createOngoingPeriod)),
                _ActionChip('创建历史经期（5天前~2天前）',
                    () => _run('创建历史经期', _createHistoryPeriod)),
                _ActionChip('列出全部经期', () => _run('列出全部经期', _listPeriods)),
                _ActionChip('SyncMeta 状态', () => _run('SyncMeta 状态', _showSyncMeta)),
                _ActionChip('生成模拟历史（4周期）',
                    () => _run('生成模拟历史', _seedDemoHistory)),
                _ActionChip('经期预测结果', () => _run('经期预测', _runPredict)),
                _ActionChip('☁ OSS 同步面板', _openOssPanel),
                _ActionChip('⚠ 清空全部数据', () => _run('清空全部数据', _wipeAll)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text('当前数据量：DailyLog ${db.dailyLogs.countSync()} 条 · '
                    'PeriodRecord ${db.periodRecords.countSync()} 条',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const Divider(height: 16),
          Expanded(
            child: Container(
              width: double.infinity,
              color: AppColors.tideMist,
              child: SelectionArea(
                child: ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: _logs.length,
                  itemBuilder: (_, index) {
                    final log = _logs[_logs.length - 1 - index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        log,
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: log.startsWith('✗')
                              ? AppColors.danger
                              : log.startsWith('✓')
                                  ? AppColors.tideDeep
                                  : AppColors.textPrimary,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip(this.label, this.onPressed);

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onPressed,
      backgroundColor: AppColors.card,
      side: const BorderSide(color: AppColors.divider),
    );
  }
}
