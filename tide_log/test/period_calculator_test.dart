import 'package:flutter_test/flutter_test.dart';
import 'package:tide_log/algorithms/period_calculator.dart';
import 'package:tide_log/core/constants.dart';
import 'package:tide_log/core/date_utils.dart';
import 'package:tide_log/models/period_record.dart';

/// 构造经期记录：start 为开始日；endOffset 为持续天数（null = 进行中）。
List<PeriodRecord> buildPeriods(List<DateTime> starts, {int? endOffset}) {
  return starts
      .map((s) => PeriodRecord.create(s,
          end: endOffset == null ? null : addDays(s, endOffset)))
      .toList();
}

void main() {
  group('冷启动与数据成熟度', () {
    test('无任何记录：默认 28 天周期 / 5 天经期，无锚点', () {
      final p = PeriodCalculator.predict(
          records: [], today: DateTime(2026, 10, 24));

      expect(p.quality, PredictionQuality.coldStart);
      expect(p.cycleLength, PeriodDefaults.defaultCycleLength);
      expect(p.periodLength, PeriodDefaults.defaultPeriodLength);
      expect(p.hasAnchor, isFalse);
      expect(p.nextPeriodStart, isNull);
      expect(p.ovulationDate, isNull);
      expect(p.phaseOn(DateTime(2026, 10, 24)), CyclePhase.safe);
      expect(p.cycleDayOn(DateTime(2026, 10, 24)), isNull);
    });

    test('仅一条已结束记录：经期长度取实际值，周期用默认基准', () {
      final records = buildPeriods([DateTime(2026, 10, 1)], endOffset: 4);
      final p = PeriodCalculator.predict(
          records: records, today: DateTime(2026, 10, 10));

      expect(p.quality, PredictionQuality.coldStart, reason: '0 个周期样本');
      expect(p.cycleLength, 28);
      expect(p.periodLength, 5, reason: '实际经期 10-01~10-05 共 5 天');
      expect(p.nextPeriodStart, DateTime(2026, 10, 29));
    });

    test('两条记录：以实际周期天数为临时基准', () {
      final records =
          buildPeriods([DateTime(2026, 10, 1), DateTime(2026, 10, 31)], endOffset: 4);
      final p = PeriodCalculator.predict(
          records: records, today: DateTime(2026, 11, 5));

      expect(p.quality, PredictionQuality.temporary);
      expect(p.cycleLength, 30);
      expect(p.nextPeriodStart, DateTime(2026, 11, 30));
      expect(p.usedCycleSamples, [30]);
    });
  });

  group('加权移动平均（WMA）', () {
    test('权重递增：近期样本权重更高', () {
      // 旧→新 [30, 28]：权重 1、2 → (30*1 + 28*2) / 3 = 28.67
      expect(PeriodCalculator.weightedMovingAverage([30, 28]), closeTo(28.667, 0.001));
      expect(PeriodCalculator.weightedMovingAverage([28]), 28);
    });

    test('3 个以上样本进入个性化 WMA', () {
      // 周期序列 [28, 30, 26] → (28*1+30*2+26*3)/6 = 27.67 → 28
      final records = buildPeriods([
        DateTime(2026, 1, 1),
        DateTime(2026, 1, 29),
        DateTime(2026, 2, 28),
        DateTime(2026, 3, 26),
      ], endOffset: 4);
      final p = PeriodCalculator.predict(
          records: records, today: DateTime(2026, 4, 1));

      expect(p.quality, PredictionQuality.personalized);
      expect(p.rawCycleLength, closeTo(27.667, 0.001));
      expect(p.cycleLength, 28);
      expect(p.usedCycleSamples, [28, 30, 26]);
      expect(p.nextPeriodStart, DateTime(2026, 4, 23));
    });

    test('超过 6 个样本时只取最近 6 个', () {
      // 8 次开始日 → 7 个周期 [20,22,24,26,28,30,32]，取后 6 个
      var day = DateTime(2026, 1, 1);
      final starts = <DateTime>[day];
      final gaps = [20, 22, 24, 26, 28, 30, 32];
      for (final g in gaps) {
        day = addDays(day, g);
        starts.add(day);
      }
      final p = PeriodCalculator.predict(
          records: buildPeriods(starts, endOffset: 3),
          today: addDays(day, 3));

      expect(p.usedCycleSamples, [22, 24, 26, 28, 30, 32]);
      // (22*1+24*2+26*3+28*4+30*5+32*6)/21 = 602/21 ≈ 28.67 → 29
      expect(p.rawCycleLength, closeTo(28.667, 0.001));
      expect(p.cycleLength, 29);
    });
  });

  group('异常值过滤（核心边界）', () {
    test('<15 天与 >60 天的极端周期被剔除，不参与平均', () {
      // 周期序列 [10, 28, 75, 30, 26]：10 与 75 为异常
      var day = DateTime(2026, 6, 1);
      final starts = <DateTime>[day];
      for (final g in [10, 28, 75, 30, 26]) {
        day = addDays(day, g);
        starts.add(day);
      }
      final p = PeriodCalculator.predict(
          records: buildPeriods(starts, endOffset: 3),
          today: addDays(day, 3));

      expect(p.outlierCycles, [10, 75]);
      expect(p.usedCycleSamples, [28, 30, 26]);
      expect(p.quality, PredictionQuality.personalized);
      expect(p.cycleLength, 28);
    });

    test('全部周期异常时回退冷启动默认值', () {
      final records = buildPeriods([
        DateTime(2026, 8, 1),
        DateTime(2026, 8, 11), // 周期 10 天
        DateTime(2026, 11, 4), // 周期 85 天
      ], endOffset: 2);
      final p = PeriodCalculator.predict(
          records: records, today: DateTime(2026, 11, 10));

      expect(p.quality, PredictionQuality.coldStart);
      expect(p.cycleLength, 28);
      expect(p.outlierCycles, [10, 85]);
      expect(p.nextPeriodStart, DateTime(2026, 12, 2));
    });
  });

  group('排卵日 / 易孕期 / 安全期推算', () {
    // 锚点场景：周期 [28,30,26] → 28 天，下次经期 2026-04-23
    final records = buildPeriods([
      DateTime(2026, 1, 1),
      DateTime(2026, 1, 29),
      DateTime(2026, 2, 28),
      DateTime(2026, 3, 26),
    ], endOffset: 4);
    final p = PeriodCalculator.predict(
        records: records, today: DateTime(2026, 4, 1));

    test('排卵日 = 下次经期开始日倒推 14 天', () {
      expect(p.nextPeriodStart, DateTime(2026, 4, 23));
      expect(p.ovulationDate, DateTime(2026, 4, 9));
    });

    test('易孕窗口 = 排卵日前 5 后 4，恰好 10 天', () {
      expect(p.fertileWindowStart, DateTime(2026, 4, 4));
      expect(p.fertileWindowEnd, DateTime(2026, 4, 13));
      expect(daysBetween(p.fertileWindowStart!, p.fertileWindowEnd!) + 1, 10);
    });

    test('phaseOn 全阶段判定', () {
      expect(p.phaseOn(DateTime(2026, 4, 1)), CyclePhase.safe,
          reason: '滤泡早期');
      expect(p.phaseOn(DateTime(2026, 4, 3)), CyclePhase.safe);
      expect(p.phaseOn(DateTime(2026, 4, 4)), CyclePhase.fertile, reason: '易孕第一天');
      expect(p.phaseOn(DateTime(2026, 4, 8)), CyclePhase.fertile);
      expect(p.phaseOn(DateTime(2026, 4, 9)), CyclePhase.ovulationDay);
      expect(p.phaseOn(DateTime(2026, 4, 10)), CyclePhase.fertile);
      expect(p.phaseOn(DateTime(2026, 4, 13)), CyclePhase.fertile, reason: '易孕最后一天');
      expect(p.phaseOn(DateTime(2026, 4, 14)), CyclePhase.safe, reason: '黄体期');
      expect(p.phaseOn(DateTime(2026, 4, 22)), CyclePhase.safe);
      expect(p.phaseOn(DateTime(2026, 4, 23)), CyclePhase.predictedMenstruation);
      expect(p.phaseOn(DateTime(2026, 4, 27)), CyclePhase.predictedMenstruation,
          reason: '预测经期第 5 天（periodLength=5）');
      expect(p.phaseOn(DateTime(2026, 4, 28)), CyclePhase.safe,
          reason: '下一周期的滤泡早期');
    });

    test('未来多个周期的预测与下一周期排卵', () {
      expect(p.upcomingPeriodStarts(3),
          [DateTime(2026, 4, 23), DateTime(2026, 5, 21), DateTime(2026, 6, 18)]);
      expect(p.nextOvulationFrom(DateTime(2026, 4, 1)), DateTime(2026, 4, 9));
      expect(p.nextOvulationFrom(DateTime(2026, 4, 10)), DateTime(2026, 5, 7),
          reason: '当期排卵已过则取下一周期');
    });
  });

  group('实际记录与进行中经期', () {
    test('实际经期优先于预测判定', () {
      final records = buildPeriods([DateTime(2026, 4, 20)], endOffset: 4);
      final p = PeriodCalculator.predict(
          records: records, today: DateTime(2026, 4, 22));

      expect(p.phaseOn(DateTime(2026, 4, 22)), CyclePhase.menstruation);
      expect(p.phaseOn(DateTime(2026, 4, 24)), CyclePhase.menstruation,
          reason: '经期最后一天');
      expect(p.phaseOn(DateTime(2026, 4, 25)), CyclePhase.safe);
      expect(p.cycleDayOn(DateTime(2026, 4, 22)), 3, reason: '经期第 3 天');
    });

    test('进行中经期：今日处于经期并正确计数', () {
      final records = buildPeriods([DateTime(2026, 4, 21)]); // 无结束日
      final p = PeriodCalculator.predict(
          records: records, today: DateTime(2026, 4, 24));

      expect(p.phaseOn(DateTime(2026, 4, 24)), CyclePhase.menstruation);
      expect(p.cycleDayOn(DateTime(2026, 4, 24)), 4);
      expect(p.nextPeriodStart, DateTime(2026, 5, 19), reason: '4-21 + 28 天');
    });

    test('上次经期远早于今天时，预测向前滚动到未来', () {
      final records = buildPeriods([DateTime(2026, 1, 1)], endOffset: 4);
      final p = PeriodCalculator.predict(
          records: records, today: DateTime(2026, 4, 11));

      // 1-1 + 28k >= 4-11 的最小 k=4 → 1-1 + 112 = 4-23
      expect(p.nextPeriodStart, DateTime(2026, 4, 23));
      expect(daysBetween(DateTime(2026, 4, 11), p.nextPeriodStart!), 12);
    });
  });

  group('经期长度基准', () {
    test('多周期 WMA 且异常长度（>14 天）被过滤', () {
      final records = [
        PeriodRecord.create(DateTime(2026, 1, 1), end: DateTime(2026, 1, 4)), // 4 天
        PeriodRecord.create(DateTime(2026, 1, 29), end: DateTime(2026, 2, 2)), // 5 天
        PeriodRecord.create(DateTime(2026, 3, 1), end: DateTime(2026, 3, 21)), // 21 天 → 异常
      ];
      final p = PeriodCalculator.predict(
          records: records, today: DateTime(2026, 4, 1));

      expect(p.periodLength, 5, reason: '异常长度 21 被剔除，(4+5)/2=4.5 → 5');
      expect(p.cycleLength, 30, reason: '周期 [28, 31] 临时基准均值 29.5 → 30');
      expect(p.quality, PredictionQuality.temporary);
    });
  });
}
