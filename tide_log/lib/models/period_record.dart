import 'package:isar_community/isar.dart';

import '../core/constants.dart';

import '../core/date_utils.dart';

part 'period_record.g.dart';

/// 经期记录来源。code 固化规则同 FlowLevel。
enum RecordSource {
  manual(0, '手动记录'),
  inferred(1, '由打卡推算');

  const RecordSource(this.code, this.label);

  final int code;
  final String label;

  static RecordSource fromCode(int code) =>
      values.firstWhere((e) => e.code == code, orElse: () => RecordSource.manual);
}

/// 一次经期事件（从开始到结束为一个完整 episode）。
///
/// [endDate] 为 null 表示「进行中」——用户已标记开始但尚未结束，
/// 或忘记标记结束（算法侧会按打卡数据兜底推算结束日）。
@Collection()
class PeriodRecord {
  PeriodRecord();

  /// 便捷构造：创建一条经期记录。
  factory PeriodRecord.create(DateTime start, {DateTime? end}) {
    final now = DateTime.now();
    return PeriodRecord()
      ..startDate = normalizeDate(start)
      ..endDate = end == null ? null : normalizeDate(end)
      ..createdAt = now
      ..updatedAt = now;
  }

  Id id = Isar.autoIncrement;

  /// 经期开始日（本地日历日，归一化到 00:00）。
  @Index()
  late DateTime startDate;

  /// 经期结束日（null = 进行中）。
  DateTime? endDate;

  /// 记录来源（手动 / 由每日打卡的经量数据推算）。
  int sourceCode = RecordSource.manual.code;

  /// 创建时间。
  late DateTime createdAt;

  /// 最近修改时间。
  @Index()
  late DateTime updatedAt;

  @ignore
  RecordSource get source => RecordSource.fromCode(sourceCode);

  set source(RecordSource value) => sourceCode = value.code;

  bool get isOngoing => endDate == null;

  /// 该经期事件是否覆盖指定日历日（按日粒度比较）。
  ///
  /// 进行中（endDate == null）的事件最多向后覆盖 [PeriodDefaults.maxPeriodDurationDays]
  /// 天——现实中的经期不会持续数周，超过上限视为漏记结束，
  /// 避免一个未关闭的旧经期吞掉之后所有日期的归属判断。
  bool covers(DateTime day) {
    final d = normalizeDate(day);
    if (d.isBefore(startDate)) return false;
    final end = endDate ??
        addDays(startDate, PeriodDefaults.maxPeriodDurationDays);
    return !d.isAfter(end);
  }

  /// 备份序列化（OSS 整体 JSON 覆盖同步）。字段名即云端格式，勿随意改动。
  Map<String, dynamic> toJson() => {
        'id': id,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'sourceCode': sourceCode,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  /// 从备份反序列化；日期统一归一化到本地日历日。
  factory PeriodRecord.fromJson(Map<String, dynamic> json) => PeriodRecord()
        ..id = json['id'] as int
        ..startDate =
            normalizeDate(DateTime.parse(json['startDate'] as String))
        ..endDate = json['endDate'] == null
            ? null
            : normalizeDate(DateTime.parse(json['endDate'] as String))
        ..sourceCode = json['sourceCode'] as int? ?? RecordSource.manual.code
        ..createdAt = DateTime.parse(json['createdAt'] as String)
        ..updatedAt = DateTime.parse(json['updatedAt'] as String);
}
