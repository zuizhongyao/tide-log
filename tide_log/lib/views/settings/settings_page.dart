import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../services/oss_client.dart';
import '../../services/oss_config.dart';
import '../../services/oss_sync_service.dart';
import '../../providers/app_data_provider.dart';
import '../../services/database_service.dart';
import '../debug/db_debug_page.dart';
import '../widgets/debug_panel_action.dart';

/// 设置页：云端同步（OSS 凭证与操作）、数据管理、关于。
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _akController = TextEditingController();
  final _skController = TextEditingController();
  final _endpointController = TextEditingController();
  final _bucketController = TextEditingController();
  final _passwordController = TextEditingController();

  final OssConfigService _configService = OssConfigService();
  OssSyncService? _syncService;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _syncService = OssSyncService(
      database: DatabaseService.instance,
      ossClient: DioOssClient(),
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
  }

  OssConfig? _configFromForm() {
    final config = OssConfig(
      accessKeyId: _akController.text.trim(),
      accessKeySecret: _skController.text.trim(),
      endpoint: _endpointController.text.trim(),
      bucket: _bucketController.text.trim(),
      encryptionPassword: _passwordController.text.trim(),
    );
    return config.isComplete ? config : null;
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;
    await _configService.save(_configFromForm()!);
    _toast('凭证已保存到安全存储');
  }

  Future<void> _runSync(SyncMode mode, String label) async {
    if (_syncing) return;
    final config = _configFromForm();
    if (config == null) {
      _toast('请先填写并保存完整的 OSS 凭证');
      return;
    }
    setState(() => _syncing = true);
    try {
      final result =
          await _syncService!.sync(config: config, mode: mode);
      _toast(result.message);
    } on SyncException catch (e) {
      _toast('$label失败：${e.message}');
    } catch (e) {
      _toast('$label异常：$e');
    } finally {
      if (mounted) setState(() => _syncing = false);
      // ignore: use_build_context_synchronously
      context.read<AppDataProvider>().refresh();
    }
  }

  Future<void> _clearConfig() async {
    final confirmed = await _confirm('清除凭证', '将从本机安全存储中删除 OSS 凭证（云端备份不受影响）。');
    if (!confirmed) return;
    await _configService.clear();
    if (!mounted) return;
    setState(() {
      _akController.clear();
      _skController.clear();
      _endpointController.clear();
      _bucketController.clear();
      _passwordController.clear();
    });
    _toast('凭证已清除');
  }

  Future<void> _wipeData() async {
    final confirmed =
        await _confirm('清空全部数据', '将删除本机全部经期与打卡记录，且不可恢复（云端备份不受影响）。确定继续吗？');
    if (!confirmed) return;
    final db = DatabaseService.instance;
    for (final log in db.dailyLogs.getAllSync().toList()) {
      await db.dailyLogs.deleteByDate(log.date);
    }
    for (final record in db.periodRecords.getAllSync().toList()) {
      await db.periodRecords.delete(record.id);
    }
    // ignore: use_build_context_synchronously
    context.read<AppDataProvider>().refresh();
    _toast('本机数据已清空');
  }

  Future<bool> _confirm(String title, String content) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确定')),
        ],
      ),
    );
    return result ?? false;
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  String _formatTime(DateTime? at) =>
      at == null ? '从未' : DateFormat('yyyy-MM-dd HH:mm').format(at);

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
    final data = context.watch<AppDataProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        actions: const [DebugPanelAction(), SizedBox(width: 4)],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            // ---- 同步状态 ----
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          data.hasUnsyncedChanges
                              ? Icons.cloud_upload_outlined
                              : Icons.cloud_done_outlined,
                          size: 20,
                          color: data.hasUnsyncedChanges
                              ? AppColors.coral
                              : AppColors.safe,
                        ),
                        const SizedBox(width: 8),
                        const Text('云端同步状态',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '本地最近修改：${_formatTime(data.lastLocalChangeAt)}\n'
                      '上次同步成功：${_formatTime(data.lastSyncedAt)}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary, height: 1.6),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // ---- OSS 凭证 ----
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('阿里云 OSS 凭证',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    const Text('仅保存在本机安全存储，随备份上传的只有加密后的数据',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _akController,
                      decoration: const InputDecoration(
                          labelText: 'AccessKeyId',
                          hintText: '在阿里云 RAM 控制台创建'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? '必填' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _skController,
                      obscureText: true,
                      decoration: const InputDecoration(
                          labelText: 'AccessKeySecret'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? '必填' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _endpointController,
                      decoration: const InputDecoration(
                          labelText: 'Endpoint',
                          hintText: 'oss-cn-hangzhou.aliyuncs.com'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? '必填' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _bucketController,
                      decoration: const InputDecoration(
                          labelText: 'Bucket',
                          hintText: '建议私有读写权限'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? '必填' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: '加密密码（可选）',
                        helperText: '留空明文上传；填写后 AES-256 加密，忘记将无法解密',
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _saveConfig,
                          icon: const Icon(Icons.save_outlined, size: 18),
                          label: const Text('保存凭证'),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: _clearConfig,
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('清除'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // ---- 同步操作 ----
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('同步操作',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _syncing
                                ? null
                                : () => _runSync(SyncMode.auto, '一键同步'),
                            icon: _syncing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.sync, size: 18),
                            label: const Text('一键同步'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _syncing
                                ? null
                                : () => _runSync(SyncMode.forceUpload, '强制上传'),
                            icon: const Icon(Icons.upload_outlined, size: 18),
                            label: const Text('强制上传'),
                            style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.tideDeep,
                                side: const BorderSide(
                                    color: AppColors.tideLight)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _syncing
                                ? null
                                : () => _runSync(SyncMode.forcePull, '强制拉取'),
                            icon: const Icon(Icons.download_outlined, size: 18),
                            label: const Text('强制拉取'),
                            style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.tideDeep,
                                side: const BorderSide(
                                    color: AppColors.tideLight)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // ---- 数据管理 ----
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('数据管理',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _wipeData,
                      icon: const Icon(Icons.delete_forever_outlined, size: 18),
                      label: const Text('清空本机全部数据'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // ---- 关于 ----
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${AppConstants.appName} v0.1.0',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    const Text(
                      '聆听身体的潮汐。\n\n'
                      '· 纯私有：所有数据仅存于本机与你自己的 OSS\n'
                      '· 零广告：无任何商业推送与第三方埋点\n'
                      '· 单用户：本地优先，云端为加密备份与多端同步',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.7),
                    ),
                    if (kDebugMode) ...[
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const DbDebugPage()),
                        ),
                        icon: const Icon(Icons.bug_report_outlined, size: 16),
                        label: const Text('数据调试面板（debug）'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
