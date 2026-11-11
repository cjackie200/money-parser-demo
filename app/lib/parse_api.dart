import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'entry.dart';

/// 解析失败的用户可读异常,页面统一捕获此类型展示红色 SnackBar。
class ParseException implements Exception {
  final String message;

  const ParseException(this.message);

  @override
  String toString() => message;
}

/// 调用后端 POST /api/parse 的客户端。
class ParseApi {
  final http.Client _client;
  final String _baseUrl;

  /// 单次请求超时,公开只读便于测试注入短超时。
  final Duration timeout;

  ParseApi({
    required String baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 10),
  })  : _baseUrl = _normalizeBaseUrl(baseUrl),
        _client = client ?? http.Client();

  /// 去掉尾部斜杠,避免拼出 //api/parse。
  static String _normalizeBaseUrl(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  /// 调用 POST /api/parse 解析文本,成功返回 entries。
  /// 任何失败(非 200、畸形响应、超时、网络异常)都包装为 [ParseException],
  /// 不外漏底层异常,保证页面不红屏。
  Future<List<Entry>> parse(String text) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/api/parse'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'text': text}),
          )
          .timeout(timeout);

      if (response.statusCode != 200) {
        throw ParseException(_serverMessage(response) ?? '解析失败 (HTTP ${response.statusCode})');
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final entries = (decoded as Map<String, dynamic>)['entries'] as List;
      return entries
          .map((item) => Entry.fromJson(item as Map<String, dynamic>))
          .toList();
    } on ParseException {
      rethrow;
    } on TimeoutException {
      throw const ParseException('连接超时，请检查服务是否启动');
    } on SocketException {
      throw const ParseException('连接超时，请检查服务是否启动');
    } on http.ClientException {
      throw const ParseException('连接超时，请检查服务是否启动');
    } catch (_) {
      // 兜底: TypeError、FormatException 等一切意外都转成用户可读异常
      throw const ParseException('解析失败，请稍后重试');
    }
  }

  /// 尝试从错误响应体取后端 errors[0],取不到返回 null。
  static String? _serverMessage(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final errors = (decoded as Map<String, dynamic>)['errors'] as List;
      if (errors.isNotEmpty) {
        return errors.first as String;
      }
    } catch (_) {
      // 错误体解析不了就交给调用方用通用文案
    }
    return null;
  }
}
