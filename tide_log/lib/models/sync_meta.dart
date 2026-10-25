import 'package:isar_community/isar.dart';

part 'sync_meta.g.dart';

/// 同步元数据（全库单例，固定 id = 0）。
///
/// 第四步 OSS 同服的判据来源：
/// - [lastLocalChangeAt]：本地数据最近一次任何写操作的时间，
///   与云端文件的 updated_at 比较，新的一方整体覆盖旧的一方；
/// - [lastSyncedAt] / [lastRemoteStamp]：上次同步成功的时间与云端标识，
///   用于「无变化则跳过上传」的省流优化。
@Collection()
class SyncMeta {
  Id id = 0;

  DateTime? lastLocalChangeAt;

  DateTime? lastSyncedAt;

  String? lastRemoteStamp;
}
