import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:encrypt/encrypt.dart';

import '../core/constants.dart';
import 'oss_sync_service.dart' show SyncException;

/// AES-256 备份加密服务。
///
/// 备份文件格式：
/// - 加密：`TIDELOG-AES1:` + base64(16字节随机IV + AES-256-CBC密文)
/// - 明文：原始 JSON 文本（依赖 OSS 私有桶权限保护）
///
/// 密钥由用户口令经 SHA-256 派生（32 字节，恰好 AES-256）；
/// 每次加密使用独立随机 IV，同一内容两次密文不同。
class AesCryptoService {
  /// 加密备份明文；[password] 为空时原样返回。
  String encodeToPayload(String plaintext, String? password) {
    if (password == null || password.trim().isEmpty) return plaintext;

    final key = _deriveKey(password);
    final iv = IV.fromSecureRandom(16);
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc, padding: 'PKCS7'));
    final cipher = encrypter.encrypt(plaintext, iv: iv);

    final combined = BytesBuilder()
      ..add(iv.bytes)
      ..add(cipher.bytes);
    return '${_magicHeader()}${base64Encode(combined.toBytes())}';
  }

  /// 还原备份明文；自动识别加密/明文两种格式。
  String decodeToPlain(String payload, String? password) {
    if (!payload.startsWith(_magicHeader())) return payload;

    final pwd = password ?? '';
    if (pwd.trim().isEmpty) {
      throw const SyncException('云端备份已加密，请先在配置中填写加密密码');
    }
    try {
      final combined = base64Decode(payload.substring(_magicHeader().length));
      final iv = IV(Uint8List.sublistView(combined, 0, 16));
      final cipherBytes =
          Uint8List.sublistView(combined, 16);
      final encrypter =
          Encrypter(AES(_deriveKey(pwd), mode: AESMode.cbc, padding: 'PKCS7'));
      return encrypter.decrypt(Encrypted(cipherBytes), iv: iv);
    } on SyncException {
      rethrow;
    } catch (_) {
      throw const SyncException('解密失败：加密密码错误或备份数据已损坏');
    }
  }

  static String _magicHeader() => '${AppConstants.syncMagicHeader}-AES1:';

  static Key _deriveKey(String password) {
    final digest = crypto.sha256.convert(utf8.encode(password)).bytes;
    return Key(Uint8List.fromList(digest));
  }
}
