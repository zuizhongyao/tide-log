import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:isar_community/src/native/isar_core.dart';
import 'package:tide_log/algorithms/period_calculator.dart';
import 'package:tide_log/core/date_utils.dart';
import 'package:tide_log/models/daily_log.dart';
import 'package:tide_log/providers/app_data_provider.dart';
import 'package:tide_log/services/database_service.dart';

void main() {
  setUpAll(() async {
    final dll = File('test/native/isar_windows_x64.dll').absolute;
    if (await dll.exists()) {
      await Isar.initializeIsarCore(libraries: {IsarAbi.windowsX64: dll.path});
    } else {
      await Isar.initializeIsarCore(download: true);
    }
  });

  late Directory tempDir;
  late DatabaseService db;
  late AppDataProvider provider;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tidelog_provider_test');
    db = DatabaseService.instance;
    await db.close();
    await db.init(directory: tempDir.path);
    provider = AppDataProvider(db);
    await provider.refresh();
  });

  tearDown(() async {
    await db.close(deleteFromDisk: true);
    provider.dispose();
    await tempDir.delete(recursive: true);
  });

  final today = normalizeDate(DateTime.now());

  test('空数据：冷启动预测与引导形态', () {
    expect(provider.prediction.quality, PredictionQuality.coldStart);
    expect(provider.prediction.hasAnchor, isFalse);
    expect(provider.logOn(today), isNull);
    expect(provider.phaseOn(today), CyclePhase.safe);
  });

  test('标记经期开始后：今日处于经期且可打卡经量', () async {
    await provider.markPeriodStart(today);

    expect(provider.phaseOn(today), CyclePhase.menstruation);
    expect(provider.cycleDayOn(today), 1);
    expect(provider.ongoingPeriod, isNotNull);

    await provider.setFlow(today, FlowLevel.moderate);
    final log = provider.logOn(today);
    expect(log, isNotNull);
    expect(log!.flow, FlowLevel.moderate);

    // 同值再点取消
    await provider.setFlow(today, FlowLevel.moderate);
    expect(provider.logOn(today), isNull, reason: '唯一打卡项取消后空记录自动删除');
  });

  test('结束经期：endDate 落位且预测链路可用', () async {
    await provider.markPeriodStart(addDays(today, -3));
    await provider.setFlow(addDays(today, -3), FlowLevel.heavy);

    await provider.markPeriodEnd(today);

    final ongoing = provider.ongoingPeriod;
    expect(ongoing, isNull, reason: '已结束');
    final ended = provider.periods.first;
    expect(ended.endDate, today);
    expect(ended.isOngoing, isFalse);
    // 1 条记录 + 默认周期 28 → 有锚点预测
    expect(provider.prediction.hasAnchor, isTrue);
  });

  test('情绪/症状多选与同房开关', () async {
    await provider.toggleMood(today, 0);
    await provider.toggleMood(today, 3);
    await provider.toggleSymptom(today, 2);
    await provider.setIntercourse(today, true);

    final log = provider.logOn(today)!;
    expect(log.moodCodes, containsAll([0, 3]));
    expect(log.symptomCodes, [2]);
    expect(log.intercourse, isTrue);

    // 再次切换移除
    await provider.toggleMood(today, 0);
    expect(provider.logOn(today)!.moodCodes, [3]);
  });

  test('清空全部打卡后记录自动删除（hasAnyEntry 语义）', () async {
    await provider.setIntercourse(today, true);
    expect(provider.logOn(today), isNotNull);
    await provider.setIntercourse(today, false);
    expect(provider.logOn(today), isNull, reason: '无任何打卡内容时不应留下空记录');
  });

  test('已覆盖日期不会重复创建经期事件', () async {
    await provider.markPeriodStart(today);
    await provider.markPeriodStart(today);
    expect(provider.periods, hasLength(1));
  });

  test('同步状态快照：写入后有未同步变更', () async {
    expect(provider.hasUnsyncedChanges, isFalse);
    await provider.setFlow(today, FlowLevel.light);
    expect(provider.hasUnsyncedChanges, isTrue);

    await db.syncMeta.markSynced();
    provider.lastSyncedAt;
    // markSynced 只写 lastSyncedAt，不影响 lastLocalChangeAt
    expect(provider.hasUnsyncedChanges, isFalse,
        reason: '同步时间晚于变更时间 → 已同步');
  });

  group('历史补录（v1.1.1）', () {
    test('补录整段历史经期成功，且预测立即有锚点', () async {
      final today0 = normalizeDate(DateTime.now());
      final err = await provider.addHistoricalPeriod(
          addDays(today0, -28), addDays(today0, -24));
      expect(err, isNull);
      expect(provider.periods, hasLength(1));
      expect(provider.prediction.hasAnchor, isTrue,
          reason: '补录后算法立即有锚点，无需从今天开始记录');
      expect(provider.prediction.phaseOn(addDays(today0, -26)),
          CyclePhase.menstruation);
    });

    test('与已有记录重叠被拒绝', () async {
      final today0 = normalizeDate(DateTime.now());
      await provider.addHistoricalPeriod(
          addDays(today0, -28), addDays(today0, -24));
      final err = await provider.addHistoricalPeriod(
          addDays(today0, -26), addDays(today0, -20));
      expect(err, isNotNull);
      expect(err, contains('重叠'));
    });

    test('经期长度超过 14 天被拒绝', () async {
      final today0 = normalizeDate(DateTime.now());
      final err = await provider.addHistoricalPeriod(
          addDays(today0, -30), addDays(today0, -10));
      expect(err, contains('14'));
    });

    test('开始日期晚于今天被拒绝', () async {
      final today0 = normalizeDate(DateTime.now());
      final err = await provider.addHistoricalPeriod(
          addDays(today0, 1), addDays(today0, 3));
      expect(err, contains('晚于今天'));
    });

    test('结束日期早于开始日期被拒绝', () async {
      final today0 = normalizeDate(DateTime.now());
      final err = await provider.addHistoricalPeriod(
          addDays(today0, -5), addDays(today0, -8));
      expect(err, contains('早于'));
    });

    test('存在进行中经期时不能开始新的一段', () async {
      final today0 = normalizeDate(DateTime.now());
      await provider.markPeriodStart(today0);
      final err = await provider.markPeriodStart(addDays(today0, -40));
      expect(err, contains('先结束'));
      expect(provider.periods, hasLength(1));
    });

    test('删除经期记录', () async {
      final today0 = normalizeDate(DateTime.now());
      await provider.addHistoricalPeriod(
          addDays(today0, -28), addDays(today0, -24));
      final id = provider.periods.first.id;
      await provider.deletePeriod(id);
      expect(provider.periods, isEmpty);
      expect(provider.prediction.hasAnchor, isFalse);
    });
  });
}
