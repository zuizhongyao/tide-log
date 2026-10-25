import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../models/daily_log.dart';
import '../models/period_record.dart';
import '../models/sync_meta.dart';
import 'daily_log_repository.dart';
import 'period_record_repository.dart';
import 'sync_meta_repository.dart';

/// Isar 本地数据库服务（单例）。
///
/// 初始化后通过 [dailyLogs] / [periodRecords] / [syncMeta] 三个仓储访问数据；
/// [directory] 参数供单元测试注入临时目录，生产环境走 path_provider。
class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  Isar? _isar;
  DailyLogRepository? _dailyLogs;
  PeriodRecordRepository? _periodRecords;
  SyncMetaRepository? _syncMeta;

  bool get isReady => _isar != null;

  DailyLogRepository get dailyLogs => _require(_dailyLogs);
  PeriodRecordRepository get periodRecords => _require(_periodRecords);
  SyncMetaRepository get syncMeta => _require(_syncMeta);

  T _require<T>(T? repo) {
    if (repo == null) {
      throw StateError('DatabaseService 尚未初始化，请先调用 init()');
    }
    return repo;
  }

  /// 打开数据库（幂等，重复调用直接返回）。
  Future<void> init({String? directory}) async {
    if (_isar != null) return;

    final dir =
        directory ?? (await getApplicationDocumentsDirectory()).path;

    final isar = await Isar.open(
      [PeriodRecordSchema, DailyLogSchema, SyncMetaSchema],
      directory: dir,
      name: 'tidelog',
    );

    _isar = isar;
    final syncMetaRepo = SyncMetaRepository(isar);
    _dailyLogs = DailyLogRepository(isar, syncMeta: syncMetaRepo);
    _periodRecords = PeriodRecordRepository(isar, syncMeta: syncMetaRepo);
    _syncMeta = syncMetaRepo;
  }

  /// 关闭数据库（测试与热重载场景使用）。
  Future<void> close({bool deleteFromDisk = false}) async {
    final isar = _isar;
    if (isar == null) return;
    await isar.close(deleteFromDisk: deleteFromDisk);
    _isar = null;
    _dailyLogs = null;
    _periodRecords = null;
    _syncMeta = null;
  }
}
