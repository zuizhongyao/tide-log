import 'dart:async';

import 'package:flutter/foundation.dart';

import '../algorithms/period_calculator.dart';
import '../core/date_utils.dart';
import '../models/daily_log.dart';
import '../models/period_record.dart';
import '../services/database_service.dart';

/// 全局数据状态层：UI 与 数据库/算法 之间的唯一桥梁。
///
/// 职责：
/// - 持有经期记录与打卡记录，产出 [PeriodPrediction]；
/// - 提供快捷打卡的全部写操作（经量/痛经/情绪/症状/同房/经期起止）；
/// - 暴露同步状态快照（设置页与主页指示灯共用）。
///
/// 除自身写操作外，还订阅数据库变更流——调试面板、OSS 恢复等
/// 绕过本类的写入同样会触发 UI 刷新。
class AppDataProvider extends ChangeNotifier {
  AppDataProvider(this._db) {
    _subscriptions = [
      _db.dailyLogs.countStream().listen(
            (_) => _scheduleRefresh(),
            onError: (Object _) {},
          ),
      _db.periodRecords.countStream().listen(
            (_) => _scheduleRefresh(),
            onError: (Object _) {},
          ),
    ];
  }

  final DatabaseService _db;

  List<StreamSubscription<void>> _subscriptions = [];
  bool _refreshQueued = false;

  List<PeriodRecord> _periods = [];
  List<DailyLog> _logs = [];
  PeriodPrediction _prediction = PeriodCalculator.predict(records: const []);
  bool _ready = false;

  List<PeriodRecord> get periods => _periods;
  List<DailyLog> get logs => _logs;
  PeriodPrediction get prediction => _prediction;
  bool get ready => _ready;

  /// 数据库任何写入后的去抖刷新（同一事件循环内合并为一次）。
  void _scheduleRefresh() {
    if (_refreshQueued) return;
    _refreshQueued = true;
    Future<void>.microtask(() async {
      _refreshQueued = false;
      await refresh();
    });
  }

  /// 从数据库全量刷新（单用户数据量小，直接同步查询足够快）。
  Future<void> refresh() async {
    _periods = _db.periodRecords.getAllSync();
    _logs = _db.dailyLogs.getAllSync();
    _prediction = PeriodCalculator.predict(records: _periods);
    _ready = true;
    notifyListeners();
  }

  DailyLog? logOn(DateTime day) {
    final d = normalizeDate(day);
    for (final log in _logs) {
      if (isSameDay(log.date, d)) return log;
    }
    return null;
  }

  CyclePhase phaseOn(DateTime day) => _prediction.phaseOn(day);

  int? cycleDayOn(DateTime day) => _prediction.cycleDayOn(day);

  bool periodCovers(DateTime day) =>
      _periods.any((record) => record.covers(normalizeDate(day)));

  /// 进行中的经期事件（null = 当前无进行中经期）。
  PeriodRecord? get ongoingPeriod => _db.periodRecords.getOngoingSync();

  // ---------------------------------------------------------------------------
  // 快捷打卡写操作（同值再点一次 = 取消；全部清空时删除空记录）
  // ---------------------------------------------------------------------------

  Future<void> setFlow(DateTime day, FlowLevel? level) =>
      _mutateLog(day, (log) => log.flow = log.flow == level ? null : level);

  Future<void> setPain(DateTime day, PainLevel? level) =>
      _mutateLog(day, (log) => log.pain = log.pain == level ? null : level);

  Future<void> toggleMood(DateTime day, int code) => _mutateLog(day, (log) {
        final codes = [...log.moodCodes];
        codes.contains(code) ? codes.remove(code) : codes.add(code);
        log.moodCodes = codes;
      });

  Future<void> toggleSymptom(DateTime day, int code) => _mutateLog(day, (log) {
        final codes = [...log.symptomCodes];
        codes.contains(code) ? codes.remove(code) : codes.add(code);
        log.symptomCodes = codes;
      });

  Future<void> setIntercourse(DateTime day, bool value) =>
      _mutateLog(day, (log) => log.intercourse = value);

  Future<void> setNotes(DateTime day, String notes) =>
      _mutateLog(day, (log) => log.notes = notes.isEmpty ? null : notes);

  /// 统一写入口：取当日记录（无则建）→ 应用变更 → 保存或删除空记录 → 刷新。
  Future<void> _mutateLog(
      DateTime day, void Function(DailyLog) mutate) async {
    var log = logOn(day);
    final isNew = log == null;
    log ??= DailyLog.forDate(day);
    mutate(log);
    if (!isNew && !log.hasAnyEntry) {
      await _db.dailyLogs.deleteByDate(day);
    } else {
      await _db.dailyLogs.save(log);
    }
    await refresh();
  }

  // ---------------------------------------------------------------------------
  // 经期事件操作
  // ---------------------------------------------------------------------------

  /// 标记某日开始经期（已有覆盖该日的经期则忽略）。
  Future<void> markPeriodStart(DateTime day) async {
    final d = normalizeDate(day);
    if (periodCovers(d)) return;
    await _db.periodRecords.save(PeriodRecord.create(d));
    await refresh();
  }

  /// 结束进行中的经期（ endDate = 指定日，且不早于开始日）。
  Future<void> markPeriodEnd(DateTime day) async {
    final ongoing = _db.periodRecords.getOngoingSync();
    if (ongoing == null) return;
    final d = normalizeDate(day);
    await _db.periodRecords
        .save(ongoing..endDate = d.isBefore(ongoing.startDate) ? null : d);
    await refresh();
  }

  // ---------------------------------------------------------------------------
  // 同步状态快照（主页指示灯与设置页共用）
  // ---------------------------------------------------------------------------

  DateTime? get lastSyncedAt => _db.syncMeta.getSync().lastSyncedAt;

  DateTime? get lastLocalChangeAt => _db.syncMeta.lastLocalChangeAt;

  /// 本地有尚未上传的变更（云端为空或本地更新）。
  bool get hasUnsyncedChanges {
    final local = lastLocalChangeAt;
    final synced = lastSyncedAt;
    if (local == null) return false;
    return synced == null || local.isAfter(synced);
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }
}
