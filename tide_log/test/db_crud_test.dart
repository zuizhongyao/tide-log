import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
// IsarAbi/Abi 未从 isar.dart 公开导出，宿主测试注入本地 DLL 需要引用内部实现
import 'package:isar_community/src/native/isar_core.dart';
import 'package:tide_log/core/date_utils.dart';
import 'package:tide_log/models/daily_log.dart';
import 'package:tide_log/models/period_record.dart';
import 'package:tide_log/services/database_service.dart';

void main() {
  setUpAll(() async {
    // 宿主 VM 测试需要 Isar 原生库：优先使用仓库内置 DLL（国内网络
    // 无法直连 binaries.isar-community.dev），缺失时回退在线下载。
    final dll = File('test/native/isar_windows_x64.dll').absolute;
    if (await dll.exists()) {
      await Isar.initializeIsarCore(libraries: {IsarAbi.windowsX64: dll.path});
    } else {
      await Isar.initializeIsarCore(download: true);
    }
  });

  late Directory tempDir;
  late DatabaseService db;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tidelog_test');
    db = DatabaseService.instance;
    await db.close();
    await db.init(directory: tempDir.path);
  });

  tearDown(() async {
    await db.close(deleteFromDisk: true);
    await tempDir.delete(recursive: true);
  });

  group('DailyLogRepository', () {
    test('创建打卡并按日期读取，枚举与标签正确还原', () async {
      final day = DateTime(2026, 10, 15, 14, 30); // 带时分，应被归一化
      await db.dailyLogs.save(DailyLog.forDate(day)
        ..flow = FlowLevel.heavy
        ..pain = PainLevel.severe
        ..moodCodes = [0, 3]
        ..symptomCodes = [0, 2, 1]
        ..intercourse = true
        ..notes = '测试备注');

      final loaded = db.dailyLogs.getByDateSync(DateTime(2026, 10, 15));
      expect(loaded, isNotNull);
      expect(loaded!.date, DateTime(2026, 10, 15)); // 归一化到 00:00
      expect(loaded.flow, FlowLevel.heavy);
      expect(loaded.pain, PainLevel.severe);
      expect(loaded.moodCodes, [0, 3]);
      expect(loaded.symptomCodes, [0, 1, 2]); // 已排序去重
      expect(loaded.intercourse, isTrue);
      expect(loaded.notes, '测试备注');
      expect(loaded.hasAnyEntry, isTrue);
    });

    test('同日重复保存为 upsert：id 与 createdAt 稳定，updatedAt 刷新', () async {
      final day = DateTime(2026, 10, 16);
      final first = await db.dailyLogs.save(DailyLog.forDate(day)..flow = FlowLevel.light);
      final firstUpdatedAt = first.updatedAt;

      await Future<void>.delayed(const Duration(milliseconds: 20));
      final second = await db.dailyLogs.save(DailyLog.forDate(day)..flow = FlowLevel.heavy);

      expect(second.id, first.id, reason: '同日 upsert 必须复用 id（同步兼容的关键约束）');
      expect(second.createdAt, first.createdAt);
      expect(second.updatedAt.isAfter(firstUpdatedAt), isTrue);
      expect(db.dailyLogs.countSync(), 1, reason: '一天只允许一条记录');
      expect(db.dailyLogs.getByDateSync(day)!.flow, FlowLevel.heavy);
    });

    test('日期范围查询含两端且升序', () async {
      for (var i = 1; i <= 5; i++) {
        await db.dailyLogs.save(DailyLog.forDate(DateTime(2026, 10, i)));
      }
      final range = db.dailyLogs
          .getRangeSync(DateTime(2026, 10, 2), DateTime(2026, 10, 4));
      expect(range.length, 3);
      expect(range.map((e) => e.date.day), [2, 3, 4]);
    });

    test('标签 code 越界被过滤，防止脏数据入库', () async {
      await db.dailyLogs.save(DailyLog.forDate(DateTime(2026, 10, 17))
        ..moodCodes = [0, 99, -3]
        ..symptomCodes = [1, 1000]);
      final loaded = db.dailyLogs.getByDateSync(DateTime(2026, 10, 17))!;
      expect(loaded.moodCodes, [0]);
      expect(loaded.symptomCodes, [1]);
    });

    test('删除指定日期，updatedAt 与同步元数据联动', () async {
      final day = DateTime(2026, 10, 18);
      await db.dailyLogs.save(DailyLog.forDate(day));
      expect(await db.dailyLogs.deleteByDate(day), isTrue);
      expect(await db.dailyLogs.deleteByDate(day), isFalse, reason: '重复删除返回 false');
      expect(db.dailyLogs.getByDateSync(day), isNull);
      expect(db.syncMeta.lastLocalChangeAt, isNotNull);
    });
  });

  group('PeriodRecordRepository', () {
    test('经期事件覆盖判断与进行中查询', () async {
      final ongoing = await db.periodRecords.save(
          PeriodRecord.create(DateTime(2026, 9, 10))); // 未结束
      await db.periodRecords.save(PeriodRecord.create(
        DateTime(2026, 10, 1),
        end: DateTime(2026, 10, 5),
      ));

      expect(ongoing.isOngoing, isTrue);
      expect(db.periodRecords.getOngoingSync()!.startDate, DateTime(2026, 9, 10));
      expect(db.periodRecords.findByDateSync(DateTime(2026, 10, 3))!.startDate,
          DateTime(2026, 10, 1));
      expect(db.periodRecords.findByDateSync(DateTime(2026, 10, 6)), isNull,
          reason: '结束日次日不属于该经期');
      expect(db.periodRecords.findByDateSync(DateTime(2026, 10, 5))!.startDate,
          DateTime(2026, 10, 1), reason: '结束日当天仍属于该经期');
      expect(db.periodRecords.countSync(), 2);
    });

    test('按开始日倒序返回，删除后不再查询到', () async {
      final a = await db.periodRecords.save(PeriodRecord.create(DateTime(2026, 8, 1)));
      await db.periodRecords.save(PeriodRecord.create(DateTime(2026, 9, 1)));
      await db.periodRecords.save(PeriodRecord.create(DateTime(2026, 10, 1)));

      final all = db.periodRecords.getAllSync();
      expect(all.map((e) => e.startDate.month).toList(), [10, 9, 8]);

      expect(await db.periodRecords.delete(a.id), isTrue);
      expect(db.periodRecords.countSync(), 2);
    });
  });

  group('日期工具与存储往返', () {
    test('DateTime 存入 Isar 后日历日不发生偏移', () async {
      // 中国时区 UTC+8 的本地午夜，序列化/反序列化后必须是同一天
      final day = DateTime(2026, 2, 1);
      await db.dailyLogs.save(DailyLog.forDate(day)..flow = FlowLevel.moderate);
      final loaded = db.dailyLogs.getByDateSync(DateTime(2026, 2, 1));
      expect(loaded, isNotNull);
      expect(normalizeDate(loaded!.date), DateTime(2026, 2, 1));
      expect(loaded.date.day, 1, reason: 'UTC 往返不得把日期推到 1 月 31 日');
    });

    test('daysBetween / addDays / isSameDay', () {
      expect(daysBetween(DateTime(2026, 10, 1), DateTime(2026, 10, 29)), 28);
      expect(addDays(DateTime(2026, 10, 31), 1), DateTime(2026, 11, 1));
      expect(isSameDay(DateTime(2026, 1, 1, 23, 59), DateTime(2026, 1, 1)), isTrue);
      expect(daysInMonth(2026, 2), 28);
      expect(daysInMonth(2024, 2), 29);
    });
  });

  group('SyncMetaRepository', () {
    test('单例元数据 touch 与 markSynced', () async {
      expect(db.syncMeta.lastLocalChangeAt, isNull);
      await db.syncMeta.touch();
      final t1 = db.syncMeta.lastLocalChangeAt;
      expect(t1, isNotNull);

      await Future<void>.delayed(const Duration(milliseconds: 20));
      await db.syncMeta.touch();
      expect(db.syncMeta.lastLocalChangeAt!.isAfter(t1!), isTrue);

      await db.syncMeta.markSynced(remoteStamp: 'oss-etag-123');
      final meta = db.syncMeta.getSync();
      expect(meta.lastSyncedAt, isNotNull);
      expect(meta.lastRemoteStamp, 'oss-etag-123');
    });
  });
}
