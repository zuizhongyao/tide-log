/// 日历日期工具：本 App 一切「日期」都是本地日历日（无时区语义的整天），
/// 与 Isar 存储的绝对时间点隔离，避免 UTC 往返造成的偏移。
library;

/// 归一化到本地时区的当天 00:00。
DateTime normalizeDate(DateTime input) {
  final local = input.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// 增减天数（保持日历日语义）。
DateTime addDays(DateTime day, int days) =>
    normalizeDate(day).add(Duration(days: days));

/// 两个日历日之间的天数差（b - a）。
int daysBetween(DateTime a, DateTime b) =>
    normalizeDate(b).difference(normalizeDate(a)).inDays;

/// 是否同一天（日历日粒度）。
bool isSameDay(DateTime a, DateTime b) {
  final x = normalizeDate(a);
  final y = normalizeDate(b);
  return x.year == y.year && x.month == y.month && x.day == y.day;
}

/// 该月的天数。
int daysInMonth(int year, int month) {
  final nextMonth = month == 12 ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);
  return nextMonth.difference(DateTime(year, month, 1)).inDays;
}
