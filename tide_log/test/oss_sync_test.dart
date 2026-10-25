import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:isar_community/src/native/isar_core.dart';
import 'package:tide_log/models/daily_log.dart';
import 'package:tide_log/models/period_record.dart';
import 'package:tide_log/services/backup_codec.dart';
import 'package:tide_log/services/crypto_service.dart';
import 'package:tide_log/services/database_service.dart';
import 'package:tide_log/services/oss_client.dart';
import 'package:tide_log/services/oss_config.dart';
import 'package:tide_log/services/oss_sync_service.dart';

/// 内存版 OSS 客户端：记录写入次数与内容，供全链路同步测试。
class FakeOssClient implements OssClient {
  Uint8List? stored;
  int putCount = 0;

  @override
  Future<Uint8List?> getObject({
    required OssConfig config,
    required String objectKey,
  }) async =>
      stored;

  @override
  Future<void> putObject({
    required OssConfig config,
    required String objectKey,
    required List<int> body,
    String contentType = 'application/json',
  }) async {
    putCount++;
    stored = Uint8List.fromList(body);
  }
}

OssConfig configWithPassword({String password = 'sync-pass-123'}) =>
    OssConfig(
      accessKeyId: 'testAK',
      accessKeySecret: 'testSK',
      endpoint: 'oss-cn-hangzhou.aliyuncs.com',
      bucket: 'tidelog-test',
      encryptionPassword: password,
    );

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
  late FakeOssClient oss;
  late OssSyncService sync;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tidelog_sync_test');
    db = DatabaseService.instance;
    await db.close();
    await db.init(directory: tempDir.path);
    oss = FakeOssClient();
    sync = OssSyncService(database: db, ossClient: oss);
  });

  tearDown(() async {
    await db.close(deleteFromDisk: true);
    await tempDir.delete(recursive: true);
  });

  group('备份编解码（BackupCodec）', () {
    test('JSON 往返完整保留所有字段（含 null 与时间戳）', () {
      final log = DailyLog.forDate(DateTime(2026, 10, 10))
        ..flow = FlowLevel.heavy
        ..pain = PainLevel.moderate
        ..moodCodes = [0, 4]
        ..symptomCodes = [1, 2]
        ..intercourse = true
        ..notes = '中文备注 🌊';
      final ongoing = PeriodRecord.create(DateTime(2026, 10, 1));
      final ended = PeriodRecord.create(
        DateTime(2026, 9, 1),
        end: DateTime(2026, 9, 5),
      );

      final payload = BackupCodec.buildPayload(
        periodRecords: [ongoing, ended],
        dailyLogs: [log],
      );
      final restored = BackupCodec.parse(jsonEncode(payload.toJson()));

      expect(restored.dailyLogs, hasLength(1));
      final rLog = restored.dailyLogs.first;
      expect(rLog.id, log.id);
      expect(rLog.date, log.date);
      expect(rLog.flow, FlowLevel.heavy);
      expect(rLog.pain, PainLevel.moderate);
      expect(rLog.moodCodes, [0, 4]);
      expect(rLog.symptomCodes, [1, 2]);
      expect(rLog.intercourse, isTrue);
      expect(rLog.notes, '中文备注 🌊');
      expect(rLog.updatedAt, log.updatedAt);

      expect(restored.periodRecords, hasLength(2));
      final rOngoing =
          restored.periodRecords.firstWhere((e) => e.endDate == null);
      expect(rOngoing.id, ongoing.id);
      expect(rOngoing.startDate, ongoing.startDate);
      final rEnded =
          restored.periodRecords.firstWhere((e) => e.endDate != null);
      expect(rEnded.endDate, ended.endDate);
      expect(restored.dataUpdatedAt, payload.dataUpdatedAt);
    });

    test('buildPayload 的 dataUpdatedAt 取显式值与记录 updatedAt 的较大者', () {
      final old = DailyLog.forDate(DateTime(2026, 1, 1))
        ..updatedAt = DateTime(2026, 1, 1, 12);
      final payload = BackupCodec.buildPayload(
        periodRecords: const [],
        dailyLogs: [old],
        dataUpdatedAt: DateTime(2026, 6, 1),
      );
      expect(payload.dataUpdatedAt, DateTime(2026, 6, 1));
    });

    test('方向裁决矩阵', () {
      final earlier = DateTime(2026, 10, 1, 10);
      final later = DateTime(2026, 10, 1, 12);

      expect(
          BackupCodec.decideDirection(
              localChangedAt: null, cloudChangedAt: null),
          SyncDirection.inSync);
      expect(
          BackupCodec.decideDirection(
              localChangedAt: later, cloudChangedAt: null),
          SyncDirection.upload);
      expect(
          BackupCodec.decideDirection(
              localChangedAt: null, cloudChangedAt: later),
          SyncDirection.pull);
      expect(
          BackupCodec.decideDirection(
              localChangedAt: later, cloudChangedAt: earlier),
          SyncDirection.upload,
          reason: '本地更新 → 上传');
      expect(
          BackupCodec.decideDirection(
              localChangedAt: earlier, cloudChangedAt: later),
          SyncDirection.pull,
          reason: '云端更新 → 拉取');
      expect(
          BackupCodec.decideDirection(
              localChangedAt: earlier, cloudChangedAt: earlier),
          SyncDirection.inSync,
          reason: '时间戳相等 → 已同步');
    });
  });

  group('AES-256 加密（AesCryptoService）', () {
    final cryptoSvc = AesCryptoService();

    test('加解密往返（含中文与长文本），密文带魔数头', () {
      const plain = '{"dailyLogs":[{"notes":"汐语加密测试 🌊"}]}';
      final payload = cryptoSvc.encodeToPayload(plain, '口令123');

      expect(payload.startsWith('TIDELOG-AES1:'), isTrue);
      expect(payload, isNot(contains('汐语')), reason: '密文不得泄露原文片段');
      expect(cryptoSvc.decodeToPlain(payload, '口令123'), plain);
    });

    test('随机 IV：同一明文两次加密产生不同密文', () {
      final a = cryptoSvc.encodeToPayload('same', 'pwd');
      final b = cryptoSvc.encodeToPayload('same', 'pwd');
      expect(a, isNot(b));
    });

    test('错误口令解密抛出可读异常；明文直传时原样返回', () {
      final payload = cryptoSvc.encodeToPayload('secret', 'right');
      expect(() => cryptoSvc.decodeToPlain(payload, 'wrong'),
          throwsA(isA<SyncException>()));

      expect(cryptoSvc.encodeToPayload('plain-json', ''), 'plain-json');
      expect(cryptoSvc.decodeToPlain('plain-json', null), 'plain-json');
    });

    test('加密备份在未配置口令时给出明确指引', () {
      final payload = cryptoSvc.encodeToPayload('secret', 'right');
      expect(() => cryptoSvc.decodeToPlain(payload, ''),
          throwsA(isA<SyncException>()));
    });
  });

  group('OSS 签名构造', () {
    test('StringToSign 符合 OSS V1 规范', () {
      expect(
        DioOssClient.stringToSign(
          verb: 'PUT',
          date: 'Mon, 02 Jan 2006 15:04:05 GMT',
          canonicalizedResource: '/bucket/key.json',
          contentType: 'application/json',
        ),
        'PUT\n\napplication/json\nMon, 02 Jan 2006 15:04:05 GMT\n/bucket/key.json',
      );
    });

    test('签名 = base64(HMAC-SHA1(secret, stringToSign))', () {
      const sts = 'PUT\n\napplication/json\nD\n/b/k';
      final expected = base64Encode(crypto.Hmac(crypto.sha1, utf8.encode('sk'))
          .convert(utf8.encode(sts))
          .bytes);
      expect(
        DioOssClient.sign(
            accessKeySecret: 'sk',
            verb: 'PUT',
            date: 'D',
            canonicalizedResource: '/b/k',
            contentType: 'application/json'),
        expected,
      );
    });

    test('endpoint 归一化去除协议与斜杠', () {
      const cfg = OssConfig(
        accessKeyId: 'a',
        accessKeySecret: 'b',
        endpoint: 'https://oss-cn-beijing.aliyuncs.com/',
        bucket: 'bk',
      );
      expect(cfg.normalizedEndpoint, 'oss-cn-beijing.aliyuncs.com');
    });
  });

  group('OssSyncService 全链路（伪造 OSS 客户端）', () {
    test('云端为空 + 本地有数据 → 加密上传并 markSynced', () async {
      await db.dailyLogs.save(DailyLog.forDate(DateTime(2026, 10, 10))
        ..flow = FlowLevel.light);
      await db.periodRecords.save(PeriodRecord.create(
          DateTime(2026, 10, 1),
          end: DateTime(2026, 10, 5)));

      final result = await sync.sync(config: configWithPassword());

      expect(result.direction, SyncDirection.upload);
      expect(oss.putCount, 1);
      final body = utf8.decode(oss.stored!);
      expect(body.startsWith('TIDELOG-AES1:'), isTrue);
      final raw = AesCryptoService().decodeToPlain(body, 'sync-pass-123');
      final payload = BackupCodec.parse(raw);
      expect(payload.dailyLogs, hasLength(1));
      expect(payload.periodRecords, hasLength(1));
      expect(db.syncMeta.getSync().lastSyncedAt, isNotNull);
    });

    test('时间戳相等 → 已同步，不产生任何写入', () async {
      final log =
          await db.dailyLogs.save(DailyLog.forDate(DateTime(2026, 10, 10)));
      final payload = BackupCodec.buildPayload(
        periodRecords: [],
        dailyLogs: [log],
        dataUpdatedAt: db.syncMeta.lastLocalChangeAt,
      );
      oss.stored = Uint8List.fromList(utf8.encode(AesCryptoService()
          .encodeToPayload(jsonEncode(payload.toJson()), 'sync-pass-123')));

      final result = await sync.sync(config: configWithPassword());

      expect(result.direction, SyncDirection.inSync);
      expect(oss.putCount, 0);
    });

    test('云端较新 → 拉取整体恢复：清空本地、保留 id/时间戳、对齐同步判据', () async {
      // 本地旧数据
      await db.dailyLogs
          .save(DailyLog.forDate(DateTime(2026, 5, 1))..notes = 'local-old');
      final cloudTime = DateTime.now().add(const Duration(hours: 1));
      final cloudLog = DailyLog.forDate(DateTime(2026, 1, 1))
        ..id = 42
        ..flow = FlowLevel.heavy
        ..notes = 'from-cloud'
        ..updatedAt = cloudTime.subtract(const Duration(minutes: 5));
      final payload = BackupCodec.buildPayload(
        periodRecords: [],
        dailyLogs: [cloudLog],
        dataUpdatedAt: cloudTime,
      );
      oss.stored = Uint8List.fromList(utf8.encode(AesCryptoService()
          .encodeToPayload(jsonEncode(payload.toJson()), 'sync-pass-123')));

      final result = await sync.sync(config: configWithPassword());

      expect(result.direction, SyncDirection.pull);
      expect(db.dailyLogs.getByDateSync(DateTime(2026, 5, 1)), isNull,
          reason: '本地旧数据被清空');
      final restored = db.dailyLogs.getByDateSync(DateTime(2026, 1, 1));
      expect(restored, isNotNull);
      expect(restored!.id, 42, reason: '云端 id 原样保留');
      expect(restored.flow, FlowLevel.heavy);
      expect(restored.notes, 'from-cloud');
      expect(restored.updatedAt, cloudTime.subtract(const Duration(minutes: 5)),
          reason: '记录时间戳不被刷新');
      expect(db.syncMeta.lastLocalChangeAt, cloudTime,
          reason: '同步判据对齐云端');
      final second = await sync.sync(config: configWithPassword());
      expect(second.direction, SyncDirection.inSync);
    });

    test('本地较新 → 上传覆盖较旧的云端', () async {
      final oldPayload = BackupPayload(
        schemaVersion: 1,
        exportedAt: DateTime.now().subtract(const Duration(hours: 5)),
        dataUpdatedAt: DateTime.now().subtract(const Duration(hours: 5)),
        periodRecords: [],
        dailyLogs: [],
      );
      oss.stored =
          Uint8List.fromList(utf8.encode(jsonEncode(oldPayload.toJson())));

      await db.dailyLogs.save(DailyLog.forDate(DateTime(2026, 10, 24)));
      final result = await sync.sync(config: configWithPassword());

      expect(result.direction, SyncDirection.upload);
      expect(oss.putCount, 1);
    });

    test('强制模式：forcePull / forceUpload 忽略时间戳', () async {
      await db.dailyLogs.save(DailyLog.forDate(DateTime(2026, 10, 24)));
      final payload = BackupCodec.buildPayload(
        periodRecords: [],
        dailyLogs: [],
        dataUpdatedAt: DateTime.now().subtract(const Duration(days: 30)),
      );
      oss.stored = Uint8List.fromList(utf8.encode(AesCryptoService()
          .encodeToPayload(jsonEncode(payload.toJson()), 'sync-pass-123')));

      final pulled = await sync.sync(
          config: configWithPassword(), mode: SyncMode.forcePull);
      expect(pulled.direction, SyncDirection.pull);
      expect(db.dailyLogs.countSync(), 0, reason: '云端备份被整体恢复');

      final uploaded = await sync.sync(
          config: configWithPassword(), mode: SyncMode.forceUpload);
      expect(uploaded.direction, SyncDirection.upload);
      expect(oss.putCount, 1);
    });

    test('加密备份但本地未配置口令 → 给出明确异常', () async {
      oss.stored = Uint8List.fromList(utf8.encode(
          AesCryptoService().encodeToPayload('{"dataUpdatedAt":"2026-01-01T00:00:00.000"}', 'pwd')));

      expect(
        () => sync.sync(config: configWithPassword(password: '')),
        throwsA(isA<SyncException>()),
      );
    });

    test('配置不完整直接拒绝同步', () async {
      const incomplete = OssConfig(
          accessKeyId: 'a', accessKeySecret: '', endpoint: '', bucket: '');
      expect(() => sync.sync(config: incomplete),
          throwsA(isA<SyncException>()));
    });
  });
}
