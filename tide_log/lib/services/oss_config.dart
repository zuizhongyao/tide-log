import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 阿里云 OSS 连接配置（不可变值对象）。
class OssConfig {
  const OssConfig({
    required this.accessKeyId,
    required this.accessKeySecret,
    required this.endpoint,
    required this.bucket,
    this.encryptionPassword = '',
    this.objectKey = 'tide_log_backup.json',
  });

  final String accessKeyId;
  final String accessKeySecret;

  /// Endpoint 主机名，如 oss-cn-hangzhou.aliyuncs.com（可不带 https://）。
  final String endpoint;

  /// Bucket 名称。
  final String bucket;

  /// 备份加密密码（空 = 不加密直传，依赖私有桶权限保护）。
  final String encryptionPassword;

  /// 云端对象 key。
  final String objectKey;

  bool get isComplete =>
      accessKeyId.trim().isNotEmpty &&
      accessKeySecret.trim().isNotEmpty &&
      endpoint.trim().isNotEmpty &&
      bucket.trim().isNotEmpty;

  bool get isEncrypted => encryptionPassword.trim().isNotEmpty;

  /// 归一化的 Endpoint 主机（去掉协议头与末尾斜杠）。
  String get normalizedEndpoint {
    var host = endpoint.trim();
    if (host.startsWith('https://')) host = host.substring(8);
    if (host.startsWith('http://')) host = host.substring(7);
    while (host.endsWith('/')) {
      host = host.substring(0, host.length - 1);
    }
    return host;
  }

  Map<String, dynamic> toJson() => {
        'accessKeyId': accessKeyId,
        'accessKeySecret': accessKeySecret,
        'endpoint': endpoint,
        'bucket': bucket,
        'encryptionPassword': encryptionPassword,
        'objectKey': objectKey,
      };

  factory OssConfig.fromJson(Map<String, dynamic> json) => OssConfig(
        accessKeyId: json['accessKeyId'] as String? ?? '',
        accessKeySecret: json['accessKeySecret'] as String? ?? '',
        endpoint: json['endpoint'] as String? ?? '',
        bucket: json['bucket'] as String? ?? '',
        encryptionPassword: json['encryptionPassword'] as String? ?? '',
        objectKey:
            json['objectKey'] as String? ?? 'tide_log_backup.json',
      );
}

/// OSS 凭证管理：仅存于 flutter_secure_storage（Android Keystore / iOS Keychain），
/// 绝不落库到 Isar、绝不硬编码、绝不写入普通 SharedPreferences。
class OssConfigService {
  OssConfigService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'oss_config_v1';

  final FlutterSecureStorage _storage;

  Future<OssConfig?> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return OssConfig.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(OssConfig config) =>
      _storage.write(key: _key, value: jsonEncode(config.toJson()));

  Future<void> clear() => _storage.delete(key: _key);

  /// 掩码展示用（日志/设置页）：只暴露KeyId前4位。
  static String mask(OssConfig config) =>
      '${config.accessKeyId.substring(0, config.accessKeyId.length.clamp(0, 4))}****'
      '@${config.bucket}.${config.normalizedEndpoint}'
      '${config.isEncrypted ? "（加密）" : "（明文）"}';
}
