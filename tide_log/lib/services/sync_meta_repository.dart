import 'package:isar_community/isar.dart';

import '../models/sync_meta.dart';

/// 同步元数据仓储（单例行，id 固定为 0）。
class SyncMetaRepository {
  SyncMetaRepository(this._isar);

  final Isar _isar;

  IsarCollection<SyncMeta> get _collection => _isar.syncMetas;

  /// 读取元数据（不存在则返回空实例，不落库）。
  SyncMeta getSync() =>
      _collection.getSync(0) ?? SyncMeta();

  /// 本地数据最近一次变动时间（同步判据）。
  DateTime? get lastLocalChangeAt => getSync().lastLocalChangeAt;

  /// 任何数据写操作后调用：刷新本地变更时间戳。
  /// [at] 供 OSS 恢复场景对齐云端时间戳（使两端立即视为已同步）。
  Future<void> touch({DateTime? at}) async {
    final meta = getSync()..lastLocalChangeAt = at ?? DateTime.now();
    await _isar.writeTxn(() => _collection.put(meta));
  }

  /// 同步成功后调用：记录同步时刻与云端文件标识。
  Future<void> markSynced({
    DateTime? at,
    String? remoteStamp,
  }) async {
    final meta = getSync()
      ..lastSyncedAt = at ?? DateTime.now()
      ..lastRemoteStamp = remoteStamp;
    await _isar.writeTxn(() => _collection.put(meta));
  }
}
