/// 全局常量定义。
class AppConstants {
  AppConstants._();

  /// 应用中文名「汐语」。
  static const String appName = '汐语';

  /// 应用英文名 / 包名标识。
  static const String appSubtitle = 'TideLog';

  /// OSS 同步数据文件名（整体 JSON 覆盖同步的唯一对象 key）。
  static const String syncFileName = 'tide_log_backup.json';

  /// 数据加密备份的文件头标识，用于拉取时快速校验。
  static const String syncMagicHeader = 'TIDELOG';
}

/// 经期算法默认参数（冷启动基准与边界定义）。
/// 第三步的 [PeriodCalculator] 将以这里为唯一数据源。
class PeriodDefaults {
  PeriodDefaults._();

  /// 冷启动默认周期长度（天）。
  static const int defaultCycleLength = 28;

  /// 冷启动默认经期长度（天）。
  static const int defaultPeriodLength = 5;

  /// 参与加权平均的正常周期下界，低于此值视为异常（误记/点滴出血）。
  static const int minNormalCycleLength = 15;

  /// 参与加权平均的正常周期上界，高于此值视为异常（漏记/疾病/怀孕）。
  static const int maxNormalCycleLength = 60;

  /// 单次经期的最大持续天数上限（进行中记录的覆盖窗口）。
  static const int maxPeriodDurationDays = 14;

  /// 加权移动平均最多回看的周期数（最近 3-6 个月）。
  static const int maxCycleSamples = 6;

  /// 最少需要的有效周期样本数，达到后切换为「个性化基准」。
  static const int personalizedThreshold = 3;

  /// 排卵日 = 下次预测经期开始日倒推的天数（黄体期固定长度）。
  static const int ovulationLutealDays = 14;

  /// 易孕期：排卵日前推天数。
  static const int fertileDaysBeforeOvulation = 5;

  /// 易孕期：排卵日后推天数（含排卵日共 10 天窗口）。
  static const int fertileDaysAfterOvulation = 4;
}
