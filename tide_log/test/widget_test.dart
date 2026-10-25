import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:isar_community/src/native/isar_core.dart';
import 'package:tide_log/main.dart';
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
  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tidelog_ui_test');
    await DatabaseService.instance.close();
    await DatabaseService.instance.init(directory: tempDir.path);
  });

  tearDown(() async {
    await DatabaseService.instance.close(deleteFromDisk: true);
    await tempDir.delete(recursive: true);
  });

  testWidgets('四页导航壳正常渲染', (tester) async {
    await tester.pumpWidget(const TideLogApp());
    await tester.pumpAndSettle();

    // 底部导航四项
    expect(find.text('主页'), findsOneWidget);
    expect(find.text('日历'), findsOneWidget);
    expect(find.text('统计'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);

    // 默认在主页
    expect(find.text('距下次经期'), findsNothing, reason: '空数据时显示开始记录引导');
    expect(find.text('开始记录'), findsOneWidget);
  });

  testWidgets('底部导航可切换到日历与设置页', (tester) async {
    await tester.pumpWidget(const TideLogApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.text('云端同步状态'), findsOneWidget);
    expect(find.text('阿里云 OSS 凭证'), findsOneWidget);

    await tester.tap(find.text('日历'));
    await tester.pumpAndSettle();
    expect(find.text('经期'), findsOneWidget, reason: '日历页图例');
  });
}
