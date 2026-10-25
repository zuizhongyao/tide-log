import 'package:isar_community/isar.dart';

import '../core/date_utils.dart';
import '../models/daily_log.dart';
import '../models/tags.dart';
import 'sync_meta_repository.dart';

/// 每日打卡仓储：按日历日为粒度的 upsert 语义（单用户，一天最多一条）。
///
/// 所有写操作都会同时刷新 [DailyLog.updatedAt] 与 [SyncMeta.lastLocalChangeAt]，
/// 保证「整体 JSON 覆盖同步」的时间戳判据永远最新。
class DailyLogRepository {
  DailyLogRepository(this._isar, {SyncMetaRepository? syncMeta})
      : _syncMeta = syncMeta; // ignore: prefer_initializing_formals

  final Isar _isar;
  final SyncMetaRepository? _syncMeta;

  IsarCollection<DailyLog> get _collection => _isar.dailyLogs;

  /// 保存某天的打卡（自动 upsert：同日复用旧 id，保证 id 稳定可同步）。
  Future<DailyLog> save(DailyLog log) async {
    log.date = normalizeDate(log.date);
    log.moodCodes = sanitizeCodes(log.moodCodes, MoodTags.labels.length);
    log.symptomCodes =
        sanitizeCodes(log.symptomCodes, SymptomTags.labels.length);
    log.updatedAt = DateTime.now();

    final existing = getByDateSync(log.date);
    if (existing != null) {
      // 保留原始创建时间与 id，避免覆盖造成时间线失真
      log.id = existing.id;
      log.createdAt = existing.createdAt;
    }

    await _isar.writeTxn(() => _collection.put(log));
    await _syncMeta?.touch();
    return log;
  }

  /// 按日期查询（异步）。
  Future<DailyLog?> getByDate(DateTime day) async =>
      getByDateSync(day);

  /// 按日期查询（同步，Isar 同步查询在 UI isolate 上足够快）。
  DailyLog? getByDateSync(DateTime day) =>
      _collection.filter().dateEqualTo(normalizeDate(day)).findFirstSync();

  /// 查询日期区间 [start, end]（含两端，按日期升序）。
  List<DailyLog> getRangeSync(DateTime start, DateTime end) =>
      _collection
          .filter()
          .dateBetween(normalizeDate(start), normalizeDate(end))
          .sortByDate()
          .findAllSync();

  /// 全部记录（按日期升序）。
  List<DailyLog> getAllSync() => _collection.where().sortByDate().findAllSync();

  /// 删除某天的打卡。
  Future<bool> deleteByDate(DateTime day) async {
    final existing = getByDateSync(day);
    if (existing == null) return false;
    await _isar.writeTxn(() => _collection.delete(existing.id));
    await _syncMeta?.touch();
    return true;
  }

  /// 记录总数。
  int countSync() => _collection.countSync();

  /// 清空全部记录（OSS 恢复前使用；不触碰同步元数据，由调用方统一管理）。
  Future<void> deleteAllRaw() async {
    final ids = _collection.where().findAllSync().map((e) => e.id).toList();
    if (ids.isEmpty) return;
    await _isar.writeTxn(() => _collection.deleteAll(ids));
  }

  /// 原样批量写入（恢复云端备份：保留 id 与全部时间戳，不逐条刷新 updatedAt）。
  Future<void> putAllRaw(List<DailyLog> logs) async {
    if (logs.isEmpty) return;
    await _isar.writeTxn(() => _collection.putAll(logs));
  }

  /// 计数流（供 UI 响应式刷新，后续接入 Provider 后使用）。
  Stream<int> countStream() async* {
    yield countSync();
    await for (final _ in _collection.watchLazy()) {
      yield countSync();
    }
  }
}
