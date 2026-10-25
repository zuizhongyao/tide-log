import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/constants.dart';
import 'core/theme.dart';
import 'providers/app_data_provider.dart';
import 'services/database_service.dart';
import 'views/analytics/analytics_page.dart';
import 'views/calendar/calendar_page.dart';
import 'views/home/home_page.dart';
import 'views/settings/settings_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 全局锁定竖屏：经期打卡类应用以单手竖持操作为主场景
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await DatabaseService.instance.init();
  runApp(const TideLogApp());
}

/// 「汐语 TideLog」应用根组件。
class TideLogApp extends StatelessWidget {
  const TideLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '${AppConstants.appName} ${AppConstants.appSubtitle}',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: ChangeNotifierProvider(
        create: (_) => AppDataProvider(DatabaseService.instance)..refresh(),
        child: const MainShell(),
      ),
    );
  }
}

/// 底部导航壳：主页 / 日历 / 统计 / 设置。
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _pages = [HomePage(), CalendarPage(), AnalyticsPage(), SettingsPage()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: AppColors.card,
        indicatorColor: AppColors.tideLight,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.waves_outlined),
              selectedIcon: Icon(Icons.waves),
              label: '主页'),
          NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: '日历'),
          NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights),
              label: '统计'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: '设置'),
        ],
      ),
    );
  }
}

