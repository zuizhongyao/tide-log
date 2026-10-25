import 'package:isar_community/isar.dart';

import '../core/date_utils.dart';
import '../models/period_record.dart';
import 'sync_meta_repository.dart';

/// 经期事件仓储：管理「经期开始-结束」episode 的增删改查。
class PeriodRecordRepository {
  PeriodRecordRepository(this._isar, {SyncMetaRepository? syncMeta})
      : _syncMeta = syncMeta; // ignore: prefer_initializing_formals

  final Isar _isar;
  final SyncMetaRepository? _syncMeta;

  IsarCollection<PeriodRecord> get _collection => _isar.periodRecords;

  /// 保存经期事件（新建或更新；更新时刷新 updatedAt）。
  Future<PeriodRecord> save(PeriodRecord record) async {
    record.startDate = normalizeDate(record.startDate);
    record.endDate =
        record.endDate == null ? null : normalizeDate(record.endDate!);
    record.updatedAt = DateTime.now();

    if (record.id == Isar.autoIncrement) {
      record.createdAt = record.updatedAt;
    }

    await _isar.writeTxn(() => _collection.put(record));
    await _syncMeta?.touch();
    return record;
  }

  /// 全部经期事件（按开始日倒序，最近在前）。
  List<PeriodRecord> getAllSync() =>
      _collection.where().sortByStartDateDesc().findAllSync();

  /// 最近一次「进行中」的经期事件（endDate == null）。
  PeriodRecord? getOngoingSync() =>
      _collection.filter().endDateIsNull().sortByStartDateDesc().findFirstSync();

  /// 查找覆盖指定日历日的经期事件。
  PeriodRecord? findByDateSync(DateTime day) {
    final d = normalizeDate(day);
    for (final record in getAllSync()) {
      if (record.covers(d)) return record;
    }
    return null;
  }

  /// 删除指定经期事件。
  Future<bool> delete(int id) async {
    final deleted = await _isar.writeTxn(() => _collection.delete(id));
    if (deleted) await _syncMeta?.touch();
    return deleted;
  }

  /// 记录总数。
  int countSync() => _collection.countSync();

  /// 清空全部记录（OSS 恢复前使用；不触碰同步元数据）。
  Future<void> deleteAllRaw() async {
    final ids = _collection.where().findAllSync().map((e) => e.id).toList();
    if (ids.isEmpty) return;
    await _isar.writeTxn(() => _collection.deleteAll(ids));
  }

  /// 原样批量写入（恢复云端备份：保留 id 与全部时间戳）。
  Future<void> putAllRaw(List<PeriodRecord> records) async {
    if (records.isEmpty) return;
    await _isar.writeTxn(() => _collection.putAll(records));
  }

  /// 计数流（UI 响应式）。
  Stream<int> countStream() async* {
    yield countSync();
    await for (final _ in _collection.watchLazy()) {
      yield countSync();
    }
  }
}
