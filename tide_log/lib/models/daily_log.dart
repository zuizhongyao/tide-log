import 'package:isar_community/isar.dart';

import '../core/date_utils.dart';

part 'daily_log.g.dart';

/// 经量等级。code 已固化，用于跨设备同步兼容，不可重排或复用。
enum FlowLevel {
  none(0, '无'),
  light(1, '少'),
  moderate(2, '中'),
  heavy(3, '多');

  const FlowLevel(this.code, this.label);

  final int code;
  final String label;

  static FlowLevel fromCode(int code) =>
      values.firstWhere((e) => e.code == code, orElse: () => FlowLevel.moderate);
}

/// 痛经程度。code 固化规则同上。
enum PainLevel {
  none(0, '无'),
  mild(1, '轻微'),
  moderate(2, '中度'),
  severe(3, '严重');

  const PainLevel(this.code, this.label);

  final int code;
  final String label;

  static PainLevel fromCode(int code) =>
      values.firstWhere((e) => e.code == code, orElse: () => PainLevel.moderate);
}

/// 每日打卡记录：一天一条，[date] 唯一索引保证单用户下不重复。
///
/// 字段为 null / 空 的语义是「当日未记录」，区别于「记录了但没有」，
/// 这是经期预测算法区分「无数据」与「确认无出血」的关键。
@Collection()
class DailyLog {
  DailyLog();

  /// 便捷构造：为指定日期创建打卡，日期归一化并打上时间戳。
  factory DailyLog.forDate(DateTime day) {
    final now = DateTime.now();
    return DailyLog()
      ..date = normalizeDate(day)
      ..createdAt = now
      ..updatedAt = now;
  }

  Id id = Isar.autoIncrement;

  /// 记录日期（本地日历日，归一化到 00:00）。
  @Index(unique: true)
  late DateTime date;

  /// 经量（null = 未记录）。
  int? flowCode;

  /// 痛经程度（null = 未记录）。
  int? painCode;

  /// 情绪标签 code 列表，字典见 [MoodTags]。
  List<int> moodCodes = [];

  /// 身体症状 code 列表，字典见 [SymptomTags]。
  List<int> symptomCodes = [];

  /// 同房记录。
  bool intercourse = false;

  /// 文字备注。
  String? notes;

  /// 创建时间。
  late DateTime createdAt;

  /// 最近修改时间（OSS 整体覆盖同步的核心比较字段）。
  @Index()
  late DateTime updatedAt;

  @ignore
  FlowLevel? get flow =>
      flowCode == null ? null : FlowLevel.fromCode(flowCode!);

  set flow(FlowLevel? value) => flowCode = value?.code;

  @ignore
  PainLevel? get pain =>
      painCode == null ? null : PainLevel.fromCode(painCode!);

  set pain(PainLevel? value) => painCode = value?.code;

  bool get hasAnyEntry =>
      flowCode != null ||
      painCode != null ||
      moodCodes.isNotEmpty ||
      symptomCodes.isNotEmpty ||
      intercourse ||
      (notes != null && notes!.trim().isNotEmpty);

  /// 备份序列化（OSS 整体 JSON 覆盖同步）。字段名即云端格式，勿随意改动。
  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'flowCode': flowCode,
        'painCode': painCode,
        'moodCodes': moodCodes,
        'symptomCodes': symptomCodes,
        'intercourse': intercourse,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  /// 从备份反序列化；日期统一归一化到本地日历日。
  factory DailyLog.fromJson(Map<String, dynamic> json) => DailyLog()
        ..id = json['id'] as int
        ..date = normalizeDate(DateTime.parse(json['date'] as String))
        ..flowCode = json['flowCode'] as int?
        ..painCode = json['painCode'] as int?
        ..moodCodes = List<int>.from(json['moodCodes'] as List)
        ..symptomCodes = List<int>.from(json['symptomCodes'] as List)
        ..intercourse = json['intercourse'] as bool? ?? false
        ..notes = json['notes'] as String?
        ..createdAt = DateTime.parse(json['createdAt'] as String)
        ..updatedAt = DateTime.parse(json['updatedAt'] as String);
}
