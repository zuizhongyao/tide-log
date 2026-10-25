import 'dart:convert';

import '../core/constants.dart';
import '../models/daily_log.dart';
import '../models/period_record.dart';

/// 同步方向。
enum SyncDirection { upload, pull, inSync }

/// 备份数据（内存态），由 [BackupCodec] 与 JSON 互转。
class BackupPayload {
  const BackupPayload({
    required this.schemaVersion,
    required this.exportedAt,
    required this.dataUpdatedAt,
    required this.periodRecords,
    required this.dailyLogs,
  });

  final int schemaVersion;
  final DateTime exportedAt;

  /// 全库数据的最近修改时间——「整体覆盖同步」的唯一比较判据。
  final DateTime dataUpdatedAt;

  final List<PeriodRecord> periodRecords;
  final List<DailyLog> dailyLogs;

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'app': '${AppConstants.appName} ${AppConstants.appSubtitle}',
        'exportedAt': exportedAt.toIso8601String(),
        'dataUpdatedAt': dataUpdatedAt.toIso8601String(),
        'periodRecords': periodRecords.map((e) => e.toJson()).toList(),
        'dailyLogs': dailyLogs.map((e) => e.toJson()).toList(),
      };

  static BackupPayload fromJson(Map<String, dynamic> json) => BackupPayload(
        schemaVersion: json['schemaVersion'] as int? ?? 0,
        exportedAt:
            DateTime.parse(json['exportedAt'] as String),
        dataUpdatedAt:
            DateTime.parse(json['dataUpdatedAt'] as String),
        periodRecords: (json['periodRecords'] as List? ?? [])
            .map((e) => PeriodRecord.fromJson(e as Map<String, dynamic>))
            .toList(),
        dailyLogs: (json['dailyLogs'] as List? ?? [])
            .map((e) => DailyLog.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// 备份编解码与同步方向裁决（纯函数，便于单元测试）。
class BackupCodec {
  BackupCodec._();

  /// 由本地数据构建备份。
  static BackupPayload buildPayload({
    required List<PeriodRecord> periodRecords,
    required List<DailyLog> dailyLogs,
    DateTime? dataUpdatedAt,
  }) {
    DateTime? latest = dataUpdatedAt;
    for (final r in periodRecords) {
      if (latest == null || r.updatedAt.isAfter(latest)) latest = r.updatedAt;
    }
    for (final l in dailyLogs) {
      if (latest == null || l.updatedAt.isAfter(latest)) latest = l.updatedAt;
    }
    return BackupPayload(
      schemaVersion: _schemaVersion,
      exportedAt: DateTime.now(),
      dataUpdatedAt: latest ?? DateTime.now(),
      periodRecords: periodRecords,
      dailyLogs: dailyLogs,
    );
  }

  static const int _schemaVersion = 1;

  /// 解析云端 JSON；结构非法时抛 [FormatException]。
  static BackupPayload parse(String raw) {
    final trimmed = raw.trim();
    if (!trimmed.startsWith('{')) {
      throw const FormatException('备份内容不是合法的 JSON 对象');
    }
    final decoded = jsonDecode(trimmed);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('备份 JSON 结构不符合预期');
    }
    if (!decoded.containsKey('dataUpdatedAt')) {
      throw const FormatException('备份缺少 dataUpdatedAt 字段');
    }
    return BackupPayload.fromJson(decoded);
  }

  /// 同步方向裁决（整体覆盖策略的核心）：
  /// - 云端无备份：本地有数据 → 上传；本地也空 → 无需同步；
  /// - 本地更新 → 上传覆盖云端；云端更新 → 拉取覆盖本地；
  /// - 时间戳相等 → 已同步。
  static SyncDirection decideDirection({
    required DateTime? localChangedAt,
    required DateTime? cloudChangedAt,
  }) {
    if (cloudChangedAt == null) {
      return localChangedAt == null ? SyncDirection.inSync : SyncDirection.upload;
    }
    if (localChangedAt == null) return SyncDirection.pull;
    if (localChangedAt.isAfter(cloudChangedAt)) return SyncDirection.upload;
    if (cloudChangedAt.isAfter(localChangedAt)) return SyncDirection.pull;
    return SyncDirection.inSync;
  }
}
