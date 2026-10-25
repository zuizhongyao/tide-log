import '../core/constants.dart';
import '../core/date_utils.dart';
import '../models/period_record.dart';

/// 数据成熟度：决定 UI 对预测结果的置信提示与是否展示引导。
enum PredictionQuality {
  /// 冷启动：无任何有效周期样本，使用 28 天 / 5 天默认基准。
  coldStart('冷启动'),

  /// 临时基准：仅 1-2 个有效周期样本，以实际观测天数为基准。
  temporary('临时基准'),

  /// 个性化：>= 3 个有效样本，按最近 6 个做加权移动平均。
  personalized('个性化');

  const PredictionQuality(this.label);

  final String label;
}

/// 周期阶段：主页圆环与日历页染色的统一依据，
/// 取值与 AppColors 的语义色一一对应。
enum CyclePhase {
  menstruation('经期'),
  predictedMenstruation('预测经期'),
  ovulationDay('排卵日'),
  fertile('易孕期'),
  safe('安全期');

  const CyclePhase(this.label);

  final String label;
}

/// 预测结果（不可变值对象）。
///
/// 由 [PeriodCalculator.predict] 产出，UI 层只读；
/// 统计调试字段（usedCycleSamples / outlierCycles）供统计页展示
/// 「本次预测用了哪些样本、剔除了哪些异常」。
class PeriodPrediction {
  const PeriodPrediction({
    required this.quality,
    required this.cycleLength,
    required this.rawCycleLength,
    required this.periodLength,
    required this.nextPeriodStart,
    required this.usedCycleSamples,
    required this.outlierCycles,
    required List<PeriodRecord> actualRecords,
  }) : _actualRecords = actualRecords; // ignore: prefer_initializing_formals

  final PredictionQuality quality;

  /// 周期天数（WMA 四舍五入后的整数值）。
  final int cycleLength;

  /// WMA 原始值（未取整，统计页展示平滑曲线时使用）。
  final double rawCycleLength;

  /// 预测经期持续天数。
  final int periodLength;

  /// 下次经期预测开始日（已滚动到今天或之后；无记录时为 null）。
  final DateTime? nextPeriodStart;

  /// 参与本次平均的有效周期样本（旧→新）。
  final List<int> usedCycleSamples;

  /// 被剔除的异常周期样本。
  final List<int> outlierCycles;

  final List<PeriodRecord> _actualRecords;

  bool get hasAnchor => nextPeriodStart != null;

  /// 下次经期预测结束日。
  DateTime? get nextPeriodEnd =>
      nextPeriodStart == null
          ? null
          : addDays(nextPeriodStart!, periodLength - 1);

  /// 下一次经期的排卵日 = 预测开始日 - 14（黄体期固定）。
  DateTime? get ovulationDate =>
      nextPeriodStart == null
          ? null
          : addDays(nextPeriodStart!, -PeriodDefaults.ovulationLutealDays);

  /// 易孕窗口起点（排卵日前 5 天）。
  DateTime? get fertileWindowStart => ovulationDate == null
      ? null
      : addDays(ovulationDate!, -PeriodDefaults.fertileDaysBeforeOvulation);

  /// 易孕窗口终点（排卵日后 4 天），共 10 天。
  DateTime? get fertileWindowEnd => ovulationDate == null
      ? null
      : addDays(ovulationDate!, PeriodDefaults.fertileDaysAfterOvulation);

  /// 未来 count 个经期的预测开始日（含 [nextPeriodStart]）。
  List<DateTime> upcomingPeriodStarts(int count) {
    final start = nextPeriodStart;
    if (start == null || count <= 0) return const [];
    return List.generate(count, (i) => addDays(start, i * cycleLength));
  }

  /// 指定日历日所处的周期阶段。
  ///
  /// 判定优先级：实际经期记录 > 预测经期 > 排卵日 > 易孕 > 安全。
  /// 无任何数据（冷启动无锚点）时一律返回安全期。
  CyclePhase phaseOn(DateTime day) {
    final d = normalizeDate(day);

    for (final record in _actualRecords) {
      if (record.covers(d)) return CyclePhase.menstruation;
    }

    final start = nextPeriodStart;
    if (start == null) return CyclePhase.safe;

    DateTime nextBoundary;
    if (!d.isBefore(start)) {
      final k = daysBetween(start, d) ~/ cycleLength;
      final cycleStart = addDays(start, k * cycleLength);
      if (daysBetween(cycleStart, d) < periodLength) {
        return CyclePhase.predictedMenstruation;
      }
      nextBoundary = addDays(cycleStart, cycleLength);
    } else {
      nextBoundary = start;
    }

    final ovulation =
        addDays(nextBoundary, -PeriodDefaults.ovulationLutealDays);
    if (daysBetween(ovulation, d) == 0) return CyclePhase.ovulationDay;

    final fertileFrom =
        addDays(ovulation, -PeriodDefaults.fertileDaysBeforeOvulation);
    final fertileTo =
        addDays(ovulation, PeriodDefaults.fertileDaysAfterOvulation);
    if (!d.isBefore(fertileFrom) && !d.isAfter(fertileTo)) {
      return CyclePhase.fertile;
    }
    return CyclePhase.safe;
  }

  /// 指定日处于当前周期的第几天（1 基，从周期起点开始计）。
  /// 周期起点取「<= 指定日的最近一次实际或预测经期开始日」。
  int? cycleDayOn(DateTime day) {
    final d = normalizeDate(day);
    DateTime? cycleStart;

    for (final record in _actualRecords) {
      if (!record.startDate.isAfter(d) &&
          (cycleStart == null || record.startDate.isAfter(cycleStart))) {
        cycleStart = record.startDate;
      }
    }

    final start = nextPeriodStart;
    if (start != null) {
      if (d.isBefore(start)) {
        final prevBoundary = addDays(start, -cycleLength);
        if (cycleStart == null || prevBoundary.isAfter(cycleStart)) {
          cycleStart = prevBoundary;
        }
      } else {
        final k = daysBetween(start, d) ~/ cycleLength;
        final predicted = addDays(start, k * cycleLength);
        if (cycleStart == null || predicted.isAfter(cycleStart)) {
          cycleStart = predicted;
        }
      }
    }

    return cycleStart == null ? null : daysBetween(cycleStart, d) + 1;
  }

  /// 从指定日起的下一个排卵日（当期排卵已过则取下一周期）。
  DateTime? nextOvulationFrom(DateTime day) {
    final start = nextPeriodStart;
    if (start == null) return null;
    final d = normalizeDate(day);
    final current = addDays(start, -PeriodDefaults.ovulationLutealDays);
    if (!current.isBefore(d)) return current;
    return addDays(
        addDays(start, cycleLength), -PeriodDefaults.ovulationLutealDays);
  }
}

/// 经期预测算法（纯函数，无数据库依赖；仓储层负责喂数据）。
class PeriodCalculator {
  PeriodCalculator._();

  /// 基于历史经期记录产出预测。
  ///
  /// [records] 顺序不限（内部按开始日排序）；[today] 可注入以便测试确定性。
  static PeriodPrediction predict({
    required List<PeriodRecord> records,
    DateTime? today,
  }) {
    final now = normalizeDate(today ?? DateTime.now());
    final sorted = [...records]
      ..sort((a, b) => a.startDate.compareTo(b.startDate));

    // ---- 周期样本提取 + 异常值过滤（核心边界） ----
    final validCycles = <int>[];
    final outlierCycles = <int>[];
    for (var i = 1; i < sorted.length; i++) {
      final gap = daysBetween(sorted[i - 1].startDate, sorted[i].startDate);
      if (gap >= PeriodDefaults.minNormalCycleLength &&
          gap <= PeriodDefaults.maxNormalCycleLength) {
        validCycles.add(gap);
      } else {
        outlierCycles.add(gap);
      }
    }

    // ---- 周期长度基准：个性化 WMA / 临时实际值 / 冷启动默认 ----
    double rawCycle;
    PredictionQuality quality;
    if (validCycles.length >= PeriodDefaults.personalizedThreshold) {
      final from = validCycles.length - PeriodDefaults.maxCycleSamples;
      final recent =
          from > 0 ? validCycles.sublist(from) : List<int>.of(validCycles);
      rawCycle = weightedMovingAverage(recent);
      quality = PredictionQuality.personalized;
    } else if (validCycles.isNotEmpty) {
      rawCycle = validCycles.reduce((a, b) => a + b) / validCycles.length;
      quality = PredictionQuality.temporary;
    } else {
      rawCycle = PeriodDefaults.defaultCycleLength.toDouble();
      quality = PredictionQuality.coldStart;
    }
    final cycleLength = rawCycle.round();

    // ---- 经期长度基准 ----
    final endedLengths = <int>[];
    for (final record in sorted) {
      final end = record.endDate;
      if (end == null) continue;
      final length = daysBetween(record.startDate, end) + 1;
      if (length >= 1 && length <= PeriodDefaults.maxPeriodDurationDays) {
        endedLengths.add(length);
      }
    }
    final periodLength = _periodLengthOf(endedLengths);

    // ---- 锚点与下次经期开始日（始终滚动到今天或之后） ----
    DateTime? nextStart;
    if (sorted.isNotEmpty) {
      var candidate = addDays(sorted.last.startDate, cycleLength);
      while (candidate.isBefore(now)) {
        candidate = addDays(candidate, cycleLength);
      }
      nextStart = candidate;
    }

    return PeriodPrediction(
      quality: quality,
      cycleLength: cycleLength,
      rawCycleLength: rawCycle,
      periodLength: periodLength,
      nextPeriodStart: nextStart,
      usedCycleSamples: validCycles.length > PeriodDefaults.maxCycleSamples
          ? validCycles.sublist(validCycles.length - PeriodDefaults.maxCycleSamples)
          : validCycles,
      outlierCycles: outlierCycles,
      actualRecords: sorted,
    );
  }

  /// 经期长度：无样本用默认 5 天；1-2 个样本取简单平均；
  /// >= 3 个样本取最近 6 个的 WMA。
  static int _periodLengthOf(List<int> lengths) {
    if (lengths.isEmpty) return PeriodDefaults.defaultPeriodLength;
    if (lengths.length >= PeriodDefaults.personalizedThreshold) {
      final from = lengths.length - PeriodDefaults.maxCycleSamples;
      final recent =
          from > 0 ? lengths.sublist(from) : List<int>.of(lengths);
      return weightedMovingAverage(recent).round();
    }
    return (lengths.reduce((a, b) => a + b) / lengths.length).round();
  }

  /// 加权移动平均：输入按旧→新排列，最近样本权重最高（权重 1..n）。
  static double weightedMovingAverage(List<int> values) {
    if (values.isEmpty) {
      throw ArgumentError('weightedMovingAverage 要求非空列表');
    }
    var weightedSum = 0;
    var weightTotal = 0;
    for (var i = 0; i < values.length; i++) {
      final weight = i + 1;
      weightedSum += values[i] * weight;
      weightTotal += weight;
    }
    return weightedSum / weightTotal;
  }
}
