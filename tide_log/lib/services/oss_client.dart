import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import 'oss_config.dart';

/// OSS RESTful 客户端抽象（便于单元测试注入伪造实现）。
abstract class OssClient {
  /// 读取对象；云端不存在时返回 null。
  Future<Uint8List?> getObject({
    required OssConfig config,
    required String objectKey,
  });

  /// 写入对象（整体覆盖）。
  Future<void> putObject({
    required OssConfig config,
    required String objectKey,
    required List<int> body,
    String contentType = 'application/json',
  });
}

/// 基于 dio 的阿里云 OSS 客户端实现。
///
/// 鉴权采用 OSS V1 签名（HMAC-SHA1）：
/// ```
/// StringToSign = VERB \n Content-MD5 \n Content-Type \n Date \n CanonicalizedResource
/// Signature = base64(HMAC-SHA1(AccessKeySecret, StringToSign))
/// Authorization: OSS {AccessKeyId}:{Signature}
/// ```
/// 本客户端只读写单个对象，不涉及子资源与自定义头，签名构造保持最简。
class DioOssClient implements OssClient {
  DioOssClient({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
            ));

  static final DateFormat _httpDateFormat =
      DateFormat("EEE, dd MMM yyyy HH:mm:ss 'GMT'", 'en_US');

  final Dio _dio;

  /// 构造 OSS V1 签名的 StringToSign。
  static String stringToSign({
    required String verb,
    required String date,
    required String canonicalizedResource,
    String contentType = '',
  }) =>
      '$verb\n\n$contentType\n$date\n$canonicalizedResource';

  /// OSS V1 签名。
  static String sign({
    required String accessKeySecret,
    required String verb,
    required String date,
    required String canonicalizedResource,
    String contentType = '',
  }) {
    final sts = stringToSign(
      verb: verb,
      date: date,
      canonicalizedResource: canonicalizedResource,
      contentType: contentType,
    );
    final hmac = crypto.Hmac(crypto.sha1, utf8.encode(accessKeySecret));
    return base64Encode(hmac.convert(utf8.encode(sts)).bytes);
  }

  static String _httpDate(DateTime at) =>
      _httpDateFormat.format(at.toUtc());

  String _objectUrl(OssConfig config, String objectKey) =>
      'https://${config.bucket}.${config.normalizedEndpoint}/$objectKey';

  String _canonicalizedResource(OssConfig config, String objectKey) =>
      '/${config.bucket}/$objectKey';

  Map<String, String> _authHeaders({
    required OssConfig config,
    required String verb,
    required String objectKey,
    String contentType = '',
  }) {
    final date = _httpDate(DateTime.now());
    final signature = sign(
      accessKeySecret: config.accessKeySecret,
      verb: verb,
      date: date,
      canonicalizedResource:
          _canonicalizedResource(config, objectKey),
      contentType: contentType,
    );
    return {
      'Date': date,
      'Authorization': 'OSS ${config.accessKeyId}:$signature',
      if (contentType.isNotEmpty) 'Content-Type': contentType,
    };
  }

  @override
  Future<Uint8List?> getObject({
    required OssConfig config,
    required String objectKey,
  }) async {
    final response = await _dio.get<List<int>>(
      _objectUrl(config, objectKey),
      options: Options(
        headers: _authHeaders(
            config: config, verb: 'GET', objectKey: objectKey),
        responseType: ResponseType.bytes,
        validateStatus: (status) => status == 200 || status == 404,
      ),
    );
    if (response.statusCode == 404) return null;
    return Uint8List.fromList(response.data ?? []);
  }

  @override
  Future<void> putObject({
    required OssConfig config,
    required String objectKey,
    required List<int> body,
    String contentType = 'application/json',
  }) async {
    final bytes = Uint8List.fromList(body);
    await _dio.put<void>(
      _objectUrl(config, objectKey),
      data: bytes,
      options: Options(
        headers: _authHeaders(
          config: config,
          verb: 'PUT',
          objectKey: objectKey,
          contentType: contentType,
        ),
        validateStatus: (status) => status != null && status < 300,
      ),
    );
  }
}
