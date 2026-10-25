import '../core/date_utils.dart';

/// 情绪标签字典（对齐美柚常用维度）。
/// code 固化后写入 DailyLog.moodCodes，跨设备同步依赖 code 稳定，
/// 新增标签只能追加在末尾，不可重排、不可复用旧 code。
class MoodTags {
  MoodTags._();

  static const List<String> labels = [
    '开心', // 0
    '平静', // 1
    '敏感', // 2
    '烦躁', // 3
    '焦虑', // 4
    '低落', // 5
    '易怒', // 6
    '压力大', // 7
    '元气满满', // 8
    '想独处', // 9
  ];

  static String labelOf(int code) =>
      (code >= 0 && code < labels.length) ? labels[code] : '未知#$code';
}

/// 身体症状标签字典。
class SymptomTags {
  SymptomTags._();

  static const List<String> labels = [
    '乳房胀痛', // 0
    '长痘', // 1
    '腰酸', // 2
    '头痛', // 3
    '失眠', // 4
    '水肿', // 5
    '恶心', // 6
    '食欲大增', // 7
    '食欲不振', // 8
    '腹泻', // 9
    '便秘', // 10
    '疲倦嗜睡', // 11
    '小腹坠胀', // 12
    '头晕', // 13
    '怕冷', // 14
  ];

  static String labelOf(int code) =>
      (code >= 0 && code < labels.length) ? labels[code] : '未知#$code';
}

/// 打卡数据校验：过滤越界 code，防止脏数据进入数据库与云端备份。
List<int> sanitizeCodes(List<int> codes, int dictionaryLength) => codes
    .where((c) => c >= 0 && c < dictionaryLength)
    .toSet()
    .toList()
      ..sort();

/// 便捷断言：日期必须是归一化的本地日历日（00:00），否则静默修正。
DateTime ensureNormalized(DateTime day) => normalizeDate(day);
