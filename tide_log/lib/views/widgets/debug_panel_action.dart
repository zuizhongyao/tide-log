import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../debug/db_debug_page.dart';

/// debug 专属的顶部小按钮：打开数据库调试面板（release 构建不渲染）。
class DebugPanelAction extends StatelessWidget {
  const DebugPanelAction({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    return IconButton(
      icon: const Icon(Icons.bug_report_outlined, size: 20),
      tooltip: '数据库调试面板',
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const DbDebugPage()),
      ),
    );
  }
}
