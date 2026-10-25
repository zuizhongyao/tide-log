import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart' show DioException;

import '../core/date_utils.dart';
import 'backup_codec.dart';
import 'crypto_service.dart';
import 'database_service.dart';
import 'oss_client.dart';
import 'oss_config.dart';

/// 同步异常（带用户可读信息）。
class SyncException implements Exception {
  const SyncException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 同步触发模式。
enum SyncMode {
  /// 自动裁决：比较本地与云端 dataUpdatedAt，新的覆盖旧的。
  auto,

  /// 强制上传（忽略时间戳，本地覆盖云端）。
  forceUpload,

  /// 强制拉取（忽略时间戳，云端覆盖本地）。
  forcePull,
}

/// 同步结果。
class SyncResult {
  const SyncResult({
    required this.direction,
    required this.message,
    this.periodCount = 0,
    this.dailyLogCount = 0,
  });

  final SyncDirection direction;
  final String message;
  final int periodCount;
  final int dailyLogCount;
}

/// 单用户 OSS 同步服务：本地优先 + 整体 JSON 覆盖。
///
/// 流程（[SyncMode.auto]）：
/// 1. 读取云端对象（404 视为无备份）；
/// 2. 解密（按魔数头识别）并解析，取出云端 `dataUpdatedAt`；
/// 3. 与本地最近修改时间比较：
///    - 本地更新 / 云端为空 → 打包全量 JSON（可加密）上传覆盖；
///    - 云端更新 → 清空本地业务表，按备份原样恢复（id 与时间戳保留）；
///    - 相等 → 已同步，不做任何网络写操作；
/// 4. 成功后 markSynced 记录本次同步时刻与云端数据标识。
class OssSyncService {
  OssSyncService({
    required DatabaseService database,
    required OssClient ossClient,
    AesCryptoService? crypto,
  })  : _db = database,
        _client = ossClient,
        _crypto = crypto ?? AesCryptoService();

  final DatabaseService _db;
  final OssClient _client;
  final AesCryptoService _crypto;

  Future<SyncResult> sync({
    required OssConfig config,
    SyncMode mode = SyncMode.auto,
  }) async {
    if (!config.isComplete) {
      throw const SyncException('OSS 配置不完整（AccessKeyId/Secret/Endpoint/Bucket）');
    }
    final objectKey = config.objectKey;

    // ---- 1. 读取云端 ----
    Uint8List? cloudBytes;
    try {
      cloudBytes = await _client.getObject(
          config: config, objectKey: objectKey);
    } on DioException catch (e) {
      throw SyncException(
          '访问 OSS 失败（HTTP ${e.response?.statusCode ?? "?"}）：'
          '请检查 Endpoint/Bucket/凭证或网络。${_excerpt(e)}');
    }

    // ---- 2. 解密解析 ----
    BackupPayload? cloud;
    if (cloudBytes != null) {
      final String raw;
      try {
        raw = _crypto.decodeToPlain(
            utf8.decode(cloudBytes), config.encryptionPassword);
        cloud = BackupCodec.parse(raw);
      } on FormatException catch (e) {
        throw SyncException('云端备份解析失败：${e.message}');
      }
    }

    // ---- 3. 方向裁决 ----
    final localAt = _resolveLocalChangedAt();
    final cloudAt = cloud?.dataUpdatedAt;
    final direction = switch (mode) {
      SyncMode.forceUpload => SyncDirection.upload,
      SyncMode.forcePull => SyncDirection.pull,
      SyncMode.auto => BackupCodec.decideDirection(
          localChangedAt: localAt, cloudChangedAt: cloudAt),
    };

    if (direction == SyncDirection.inSync) {
      return const SyncResult(
          direction: SyncDirection.inSync, message: '本地与云端已一致，无需同步');
    }

    if (direction == SyncDirection.pull) {
      if (cloud == null) {
        throw const SyncException('云端没有备份文件，无法拉取');
      }
      await _restoreFromCloud(cloud);
      return SyncResult(
        direction: SyncDirection.pull,
        message: '已从云端恢复：云端数据较新'
            '（云端 ${cloud.dataUpdatedAt} > 本地 ${localAt ?? "空"}）',
        periodCount: cloud.periodRecords.length,
        dailyLogCount: cloud.dailyLogs.length,
      );
    }

    // ---- 4. 上传覆盖 ----
    final payload = BackupCodec.buildPayload(
      periodRecords: _db.periodRecords.getAllSync(),
      dailyLogs: _db.dailyLogs.getAllSync(),
      dataUpdatedAt: localAt,
    );
    final plaintext = jsonEncode(payload.toJson());
    final encoded = _crypto.encodeToPayload(plaintext, config.encryptionPassword);
    await _client.putObject(
      config: config,
      objectKey: objectKey,
      body: Uint8List.fromList(utf8.encode(encoded)),
    );
    await _db.syncMeta.markSynced(
        at: DateTime.now(),
        remoteStamp: payload.dataUpdatedAt.toIso8601String());
    return SyncResult(
      direction: SyncDirection.upload,
      message: '已上传备份覆盖云端'
          '（本地 ${payload.dataUpdatedAt} ${cloudAt == null ? "> 云端无备份" : "> 云端 $cloudAt"}）',
      periodCount: payload.periodRecords.length,
      dailyLogCount: payload.dailyLogs.length,
    );
  }

  /// 本地最近修改时间：优先 SyncMeta；缺失时兜底扫描全部记录。
  DateTime? _resolveLocalChangedAt() {
    final fromMeta = _db.syncMeta.lastLocalChangeAt;
    if (fromMeta != null) return fromMeta;
    DateTime? latest;
    for (final r in _db.periodRecords.getAllSync()) {
      if (latest == null || r.updatedAt.isAfter(latest)) latest = r.updatedAt;
    }
    for (final l in _db.dailyLogs.getAllSync()) {
      if (latest == null || l.updatedAt.isAfter(latest)) latest = l.updatedAt;
    }
    return latest;
  }

  /// 用云端备份整体恢复本地：先清空业务表，再原样写入（保留 id/时间戳），
  /// 最后把本地变更时间戳对齐到云端，使两端立即进入「已同步」状态。
  Future<void> _restoreFromCloud(BackupPayload cloud) async {
    final dailyLogs = cloud.dailyLogs
        .map((l) => l..date = normalizeDate(l.date))
        .toList();
    final periods = cloud.periodRecords
        .map((r) => r
          ..startDate = normalizeDate(r.startDate)
          ..endDate = r.endDate == null ? null : normalizeDate(r.endDate!))
        .toList();

    await _db.dailyLogs.deleteAllRaw();
    await _db.periodRecords.deleteAllRaw();
    await _db.dailyLogs.putAllRaw(dailyLogs);
    await _db.periodRecords.putAllRaw(periods);
    await _db.syncMeta.touch(at: cloud.dataUpdatedAt);
  }
}

// dio 的 DioException 在 oss_client 中抛出，这里只读其响应体摘要。
String _excerpt(DioException error) {
  final data = error.response?.data;
  if (data is String && data.isNotEmpty) {
    return data.length > 120 ? '${data.substring(0, 120)}…' : data;
  }
  return '';
}
