import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:money_parser_app/parse_api.dart';

/// 构造测试用 ParseApi;baseUrl 故意带尾斜杠,顺带验证归一化。
ParseApi apiWith(MockClient client, {Duration? timeout}) => ParseApi(
      baseUrl: 'http://test.local/',
      client: client,
      timeout: timeout ?? const Duration(seconds: 10),
    );

/// 构造响应。必须用 bytes + utf8: http.Response(String) 默认按 latin1 编码,
/// 中文 body 会抛 ArgumentError,掩盖被测路径。
http.Response jsonResponse(String body, int status) => http.Response.bytes(
      utf8.encode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

/// 契约 200 响应体。
String okBody() => jsonEncode({
      'entries': [
        {'amount': 35.0, 'category': '餐饮', 'direction': 'expense'},
        {'amount': 22.5, 'category': '交通', 'direction': 'expense'},
      ],
      'errors': <String>[],
    });

/// 断言抛 ParseException 且文案等于期望值。
Future<void> expectParseException(Future<void> Function() action, String want) async {
  try {
    await action();
    fail('期望抛出 ParseException');
  } on ParseException catch (e) {
    expect(e.message, want);
  }
}

void main() {
  test('200 正常响应: POST 路径与请求体正确,entries 映射正确', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return jsonResponse(okBody(), 200);
    });

    final entries = await apiWith(client).parse('午饭35打车22.5');

    expect(captured.method, 'POST');
    expect(captured.url.path, '/api/parse'); // 尾斜杠已被归一化
    expect(jsonDecode(captured.body), {'text': '午饭35打车22.5'});
    expect(entries, hasLength(2));
    expect(entries.first.amount, 35.0);
    expect(entries.first.category, '餐饮');
    expect(entries.first.direction, 'expense');
    expect(entries.last.amount, 22.5);
    expect(entries.last.category, '交通');
  });

  test('500 且带 errors 字段: 文案取后端 errors[0]', () async {
    final client = MockClient((_) async => jsonResponse(
          jsonEncode({
            'errors': ['解析超时'],
            'manual_required': true,
          }),
          500,
        ));

    await expectParseException(() => apiWith(client).parse('午饭35'), '解析超时');
  });

  test('400 且无 errors 字段: 通用 HTTP 文案', () async {
    final client = MockClient((_) async => http.Response('', 400));

    await expectParseException(() => apiWith(client).parse('午饭35'), '解析失败 (HTTP 400)');
  });

  test('200 但 body 非法 JSON: 抛 ParseException', () async {
    final client = MockClient((_) async => http.Response('not-json', 200));

    await expectParseException(() => apiWith(client).parse('午饭35'), '解析失败，请稍后重试');
  });

  test('200 但 entries 字段缺失: 抛 ParseException', () async {
    final client = MockClient((_) async => jsonResponse('{"foo":1}', 200));

    await expectParseException(() => apiWith(client).parse('午饭35'), '解析失败，请稍后重试');
  });

  test('200 但 amount 为字符串(TypeError): 抛 ParseException 不穿透', () async {
    final client = MockClient((_) async => jsonResponse(
          jsonEncode({
            'entries': [
              {'amount': '35', 'category': '餐饮', 'direction': 'expense'},
            ],
            'errors': <String>[],
          }),
          200,
        ));

    await expectParseException(() => apiWith(client).parse('午饭35'), '解析失败，请稍后重试');
  });

  test('超时: 抛 ParseException 连接超时', () async {
    final client = MockClient((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      return jsonResponse(okBody(), 200);
    });

    await expectParseException(
      () => apiWith(client, timeout: const Duration(milliseconds: 20)).parse('午饭35'),
      '连接超时，请检查服务是否启动',
    );
  });

  test('网络异常(ClientException): 抛 ParseException 连接超时', () async {
    final client = MockClient((_) async => throw http.ClientException('Connection refused'));

    await expectParseException(
      () => apiWith(client).parse('午饭35'),
      '连接超时，请检查服务是否启动',
    );
  });
}
