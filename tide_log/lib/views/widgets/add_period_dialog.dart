import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/date_utils.dart';
import '../../providers/app_data_provider.dart';

/// 补录一段历史经期：依次选择开始日与结束日。
///
/// 供新用户快速导入过去数月的记录，使预测算法从首次打开起就有数据可用。
Future<void> showAddPeriodDialog(BuildContext context) async {
  final provider = context.read<AppDataProvider>();
  final today = normalizeDate(DateTime.now());
  final twoYearsAgo = today.subtract(const Duration(days: 730));

  final start = await showDatePicker(
    context: context,
    initialDate: today,
    firstDate: twoYearsAgo,
    lastDate: today,
    helpText: '选择经期开始日',
  );
  if (start == null || !context.mounted) return;

  final lastEnd = today.isBefore(start.add(const Duration(days: 13)))
      ? today
      : start.add(const Duration(days: 13));
  final end = await showDatePicker(
    context: context,
    initialDate: start,
    firstDate: start,
    lastDate: lastEnd,
    helpText: '选择经期结束日（一般 3-7 天）',
  );
  if (end == null || !context.mounted) return;

  final error = await provider.addHistoricalPeriod(start, end);
  if (!context.mounted) return;

  final day = DateFormat('MM-dd').format;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(error ?? '已补录经期 ${day(start)} ~ ${day(end)}'),
  ));
}
