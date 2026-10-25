import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../services/crypto_service.dart';
import '../../services/database_service.dart';
import '../../services/oss_client.dart';
import '../../services/oss_config.dart';
import '../../services/oss_sync_service.dart';

/// 仅 debug 构建可达：OSS 同步调试面板（第四步）。
///
/// 填入真实阿里云凭证（保存到 flutter_secure_storage）后，
/// 可对私有 Bucket 执行真实的一键同步 / 强制上传 / 强制拉取。
class OssDebugPage extends StatefulWidget {
  const OssDebugPage({super.key});

  @override
  State<OssDebugPage> createState() => _OssDebugPageState();
}

class _OssDebugPageState extends State<OssDebugPage> {
  final _formKey = GlobalKey<FormState>();
  final _akController = TextEditingController();
  final _skController = TextEditingController();
  final _endpointController = TextEditingController();
  final _bucketController = TextEditingController();
  final _passwordController = TextEditingController();

  final OssConfigService _configService = OssConfigService();
  late final OssSyncService _syncService;

  final List<String> _logs = [];
  final DateFormat _timeFmt = DateFormat('HH:mm:ss.SSS');

  @override
  void initState() {
    super.initState();
    _syncService = OssSyncService(
      database: DatabaseService.instance,
      ossClient: DioOssClient(),
      crypto: AesCryptoService(),
    );
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await _configService.load();
    if (config == null || !mounted) return;
    setState(() {
      _akController.text = config.accessKeyId;
      _skController.text = config.accessKeySecret;
      _endpointController.text = config.endpoint;
      _bucketController.text = config.bucket;
      _passwordController.text = config.encryptionPassword;
    });
    _log('已加载本地保存的凭证：${OssConfigService.mask(config)}');
  }

  void _log(String message) {
    setState(() => _logs.add('[${_timeFmt.format(DateTime.now())}] $message'));
  }

  OssConfig _configFromForm() => OssConfig(
        accessKeyId: _akController.text.trim(),
        accessKeySecret: _skController.text.trim(),
        endpoint: _endpointController.text.trim(),
        bucket: _bucketController.text.trim(),
        encryptionPassword: _passwordController.text.trim(),
      );

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;
    final config = _configFromForm();
    await _configService.save(config);
    _log('✓ 凭证已保存至安全存储：${OssConfigService.mask(config)}');
  }

  Future<void> _runSync(SyncMode mode, String label) async {
    _log('▶ $label …');
    try {
      final config = _configFromForm();
      if (!_formKey.currentState!.validate()) return;
      final result = await _syncService.sync(config: config, mode: mode);
      _log('✓ $label：${result.message} '
          '(PeriodRecord=${result.periodCount}，DailyLog=${result.dailyLogCount})');
      _log('  同步元数据：lastSyncedAt=${DatabaseService.instance.syncMeta.getSync().lastSyncedAt}');
    } on SyncException catch (e) {
      _log('✗ $label 失败：${e.message}');
    } catch (e) {
      _log('✗ $label 异常：$e');
    }
  }

  Future<void> _clearConfig() async {
    await _configService.clear();
    _log('✓ 已清除本地保存的凭证');
  }

  @override
  void dispose() {
    _akController.dispose();
    _skController.dispose();
    _endpointController.dispose();
    _bucketController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OSS 同步调试面板')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _akController,
              decoration: const InputDecoration(
                  labelText: 'AccessKeyId',
                  hintText: 'LTAI5t开头，在阿里云 RAM 控制台创建'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '必填' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _skController,
              obscureText: true,
              decoration: const InputDecoration(
                  labelText: 'AccessKeySecret（输入即隐藏）'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '必填' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _endpointController,
              decoration: const InputDecoration(
                  labelText: 'Endpoint',
                  hintText: 'oss-cn-hangzhou.aliyuncs.com'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '必填' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bucketController,
              decoration: const InputDecoration(
                  labelText: 'Bucket',
                  hintText: '私有读写权限的桶名'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '必填' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '加密密码（可选）',
                hintText: '留空 = 明文上传；填写 = AES-256 加密',
                helperText: '忘记密码将无法解密云端备份，请牢记',
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _saveConfig,
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text('保存凭证'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _runSync(SyncMode.auto, '一键同步（自动裁决）'),
                  icon: const Icon(Icons.sync, size: 18),
                  label: const Text('一键同步'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _runSync(SyncMode.forceUpload, '强制上传'),
                  icon: const Icon(Icons.upload_outlined, size: 18),
                  label: const Text('强制上传'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _runSync(SyncMode.forcePull, '强制拉取'),
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: const Text('强制拉取'),
                ),
                TextButton.icon(
                  onPressed: _clearConfig,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('清除凭证'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '当前数据量：DailyLog ${DatabaseService.instance.dailyLogs.countSync()} 条 · '
              'PeriodRecord ${DatabaseService.instance.periodRecords.countSync()} 条',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
            const Divider(height: 24),
            Text('操作日志',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.tideMist,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectionArea(
                child: _logs.isEmpty
                    ? const Text('（等待操作）',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final log in _logs.reversed)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                log,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                  color: log.startsWith('✗')
                                      ? AppColors.danger
                                      : log.startsWith('✓')
                                          ? AppColors.tideDeep
                                          : AppColors.textPrimary,
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
