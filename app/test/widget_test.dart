import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:money_parser_app/main.dart';
import 'package:money_parser_app/parse_api.dart';

/// 契约 200 响应体。
String okBody() => jsonEncode({
      'entries': [
        {'amount': 35.0, 'category': '餐饮', 'direction': 'expense'},
        {'amount': 22.5, 'category': '交通', 'direction': 'expense'},
      ],
      'errors': <String>[],
    });

/// bytes + utf8 构造响应,避免中文 body 触发 latin1 编码错误。
http.Response jsonResponse(String body, int status) => http.Response.bytes(
      utf8.encode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

ParseApi apiWith(MockClient client) => ParseApi(
      baseUrl: 'http://test.local',
      client: client,
      timeout: const Duration(seconds: 5),
    );

Future<void> pumpApp(WidgetTester tester, ParseApi api) async {
  await tester.pumpWidget(MoneyParserApp(api: api));
}

/// 延迟指定时长后返回 200 的假上游。
MockClient delayedOk() => MockClient((_) async {
      await Future<void>.delayed(const Duration(seconds: 2));
      return jsonResponse(okBody(), 200);
    });

void main() {
  testWidgets('初始渲染: hint、解析、手动添加、空态', (WidgetTester tester) async {
    await pumpApp(tester, apiWith(MockClient((_) async => jsonResponse(okBody(), 200))));

    expect(find.text('输入一句话记账，例如：午饭35打车22'), findsOneWidget);
    expect(find.text('解析'), findsOneWidget);
    expect(find.text('手动添加'), findsOneWidget);
    expect(find.text('点击解析查看结果'), findsOneWidget);
    expect(find.byType(ListView), findsNothing);
  });

  testWidgets('200 成功: 列表被 entries 替换', (WidgetTester tester) async {
    await pumpApp(tester, apiWith(MockClient((_) async => jsonResponse(okBody(), 200))));

    await tester.tap(find.text('解析'));
    await tester.pump(); // 进入 loading
    await tester.pump(); // 响应完成

    expect(find.text('点击解析查看结果'), findsNothing);
    expect(find.text('餐饮'), findsOneWidget);
    expect(find.text('¥35.0'), findsOneWidget);
    expect(find.text('交通'), findsOneWidget);
    expect(find.text('¥22.5'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('加载中: 按钮禁用且显示进度圈', (WidgetTester tester) async {
    await pumpApp(tester, apiWith(delayedOk()));

    await tester.tap(find.text('解析'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);

    await tester.pump(const Duration(seconds: 2)); // 请求完成
    await tester.pump();
    expect(find.text('餐饮'), findsOneWidget);
  });

  testWidgets('防重复: 加载中再点不重复发请求(按钮禁用)', (WidgetTester tester) async {
    var count = 0;
    final client = MockClient((_) async {
      count++;
      await Future<void>.delayed(const Duration(seconds: 2));
      return jsonResponse(okBody(), 200);
    });
    await pumpApp(tester, apiWith(client));

    await tester.tap(find.byType(FilledButton));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byType(FilledButton)); // 已禁用
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(count, 1);
    expect(find.text('餐饮'), findsOneWidget);
  });

  testWidgets('防重复: 同帧双击仅发一次请求(回调 guard)', (WidgetTester tester) async {
    var count = 0;
    final client = MockClient((_) async {
      count++;
      await Future<void>.delayed(const Duration(seconds: 2));
      return jsonResponse(okBody(), 200);
    });
    await pumpApp(tester, apiWith(client));

    // 两次 tap 之间不 pump,两次都命中旧 onPressed 闭包
    await tester.tap(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(count, 1);
  });

  testWidgets('500: 红色 SnackBar 且手动添加仍可见', (WidgetTester tester) async {
    final client = MockClient((_) async => jsonResponse(
          jsonEncode({
            'errors': ['解析超时'],
            'manual_required': true,
          }),
          500,
        ));
    await pumpApp(tester, apiWith(client));

    await tester.tap(find.text('解析'));
    await tester.pump();
    await tester.pump();

    expect(find.text('解析超时'), findsOneWidget);
    final bar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(bar.backgroundColor, Colors.red);
    expect(find.text('手动添加'), findsOneWidget);
  });

  testWidgets('网络异常: 红色 SnackBar 连接超时且手动添加仍可见', (WidgetTester tester) async {
    final client = MockClient((_) async => throw http.ClientException('Connection refused'));
    await pumpApp(tester, apiWith(client));

    await tester.tap(find.text('解析'));
    await tester.pump();
    await tester.pump();

    expect(find.text('连接超时，请检查服务是否启动'), findsOneWidget);
    final bar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(bar.backgroundColor, Colors.red);
    expect(find.text('手动添加'), findsOneWidget);
  });

  testWidgets('手动添加: SnackBar 敬请期待', (WidgetTester tester) async {
    await pumpApp(tester, apiWith(MockClient((_) async => jsonResponse(okBody(), 200))));

    await tester.tap(find.text('手动添加'));
    await tester.pump();

    expect(find.text('敬请期待'), findsOneWidget);
  });
}
