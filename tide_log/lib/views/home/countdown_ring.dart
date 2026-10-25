import 'package:flutter/material.dart';

import '../../algorithms/period_calculator.dart';
import '../../core/date_utils.dart';
import '../../core/theme.dart';

/// 主页倒计时圆环：周期进度弧 + 中央状态文案。
///
/// 三种形态：
/// - 经期中：珊瑚色整弧 + 「经期第 N 天」；
/// - 常规：进度弧 = 周期第 N 天 / 周期长度，中央为距下次经期的天数；
/// - 冷启动无锚点：提示记录第一次经期。
class CountdownRing extends StatelessWidget {
  const CountdownRing({
    super.key,
    required this.prediction,
    required this.today,
    this.size = 250,
  });

  final PeriodPrediction prediction;
  final DateTime today;
  final double size;

  @override
  Widget build(BuildContext context) {
    final phase = prediction.phaseOn(today);
    final cycleDay = prediction.cycleDayOn(today);
    final isMenstruating = phase == CyclePhase.menstruation;
    final daysToNext = prediction.hasAnchor
        ? daysBetween(today, prediction.nextPeriodStart!)
        : null;

    final progress = (cycleDay == null || prediction.cycleLength <= 0)
        ? 0.0
        : (cycleDay / prediction.cycleLength).clamp(0.0, 1.0);

    final accent =
        isMenstruating ? AppColors.coral : AppColors.tide;

    final String headline;
    final String subline;
    if (!prediction.hasAnchor) {
      headline = '开始记录';
      subline = '标记第一次经期，\n潮汐便会开始起伏';
    } else if (isMenstruating) {
      headline = '第 $cycleDay 天';
      subline = '经期进行中';
    } else if (daysToNext == 0) {
      headline = '就是今天';
      subline = '预测经期开始日';
    } else {
      headline = '$daysToNext 天';
      subline = '距下次经期\n${CnDateFormatter.day(prediction.nextPeriodStart!)}';
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(
              progress: progress,
              accent: accent,
              trackColor: AppColors.tideLight.withValues(alpha: 0.45),
            ),
          ),
          Container(
            width: size - 44,
            height: size - 44,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.card,
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  headline,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: headline.length <= 4 ? 40 : 34,
                    fontWeight: FontWeight.w700,
                    color: accent,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subline,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.accent,
    required this.trackColor,
  });

  final double progress;
  final Color accent;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const strokeWidth = 14.0;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor;
    canvas.drawCircle(center, radius, track);

    if (progress <= 0) return;

    final rect = Rect.fromCircle(center: center, radius: radius);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -1.57,
        endAngle: 4.71,
        colors: [accent.withValues(alpha: 0.45), accent],
        transform: const GradientRotation(-1.57),
      ).createShader(rect);
    canvas.drawArc(rect, -1.57, 6.2832 * progress, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.accent != accent;
}

/// 中文日期的极简格式化（避免引入 locale 初始化）。
class CnDateFormatter {
  CnDateFormatter._();

  static String day(DateTime d) => '${d.month}月${d.day}日';

  static String full(DateTime d) => '${d.year}年${d.month}月${d.day}日';

  static String month(DateTime d) => '${d.year}年${d.month}月';
}
