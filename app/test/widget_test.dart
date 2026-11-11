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

/// 单条目 200 响应体。
String oneBody() => jsonEncode({
      'entries': [
        {'amount': 100.0, 'category': '购物', 'direction': 'expense'},
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

  testWidgets('200 成功: 首次解析列表填充', (WidgetTester tester) async {
    await pumpApp(tester, apiWith(MockClient((_) async => jsonResponse(okBody(), 200))));

    await tester.tap(find.text('解析'));
    await tester.pump();
    await tester.pump();

    expect(find.text('点击解析查看结果'), findsNothing);
    expect(find.text('餐饮'), findsOneWidget);
    expect(find.text('¥35.0'), findsOneWidget);
    expect(find.text('交通'), findsOneWidget);
    expect(find.text('¥22.5'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('累计: 第二次解析追加而不是替换', (WidgetTester tester) async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return jsonResponse(calls == 1 ? okBody() : oneBody(), 200);
    });
    await pumpApp(tester, apiWith(client));

    // 第一次: 2 条
    await tester.tap(find.text('解析'));
    await tester.pump();
    await tester.pump();
    expect(find.text('餐饮'), findsOneWidget);
    expect(find.text('交通'), findsOneWidget);

    // 第二次: 追加 1 条,共 3 条,新条目排在最上面
    await tester.tap(find.text('解析'));
    await tester.pump();
    await tester.pump();
    expect(find.text('餐饮'), findsOneWidget);
    expect(find.text('¥35.0'), findsOneWidget);
    expect(find.text('交通'), findsOneWidget);
    expect(find.text('¥22.5'), findsOneWidget);
    expect(find.text('购物'), findsOneWidget);
    expect(find.text('¥100.0'), findsOneWidget);

    final tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
    expect(tiles, hasLength(3));
    expect((tiles[0].title as Text).data, '购物'); // 最新的在最上
    expect((tiles[1].title as Text).data, '餐饮');
    expect((tiles[2].title as Text).data, '交通');
  });

  testWidgets('加载中: 按钮禁用且显示进度圈', (WidgetTester tester) async {
    await pumpApp(tester, apiWith(delayedOk()));

    await tester.tap(find.text('解析'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);

    await tester.pump(const Duration(seconds: 2));
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
    await tester.tap(find.byType(FilledButton));
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

  testWidgets('手动添加: 表单提交后条目进列表', (WidgetTester tester) async {
    await pumpApp(tester, apiWith(MockClient((_) async => jsonResponse(okBody(), 200))));

    await tester.tap(find.text('手动添加'));
    await tester.pumpAndSettle();

    // 底部表单出现
    expect(find.text('金额'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, '12.5');
    // 选分类: 打开下拉,选「交通」
    await tester.tap(find.text('餐饮').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('交通').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    expect(find.text('交通'), findsOneWidget);
    expect(find.text('¥12.5'), findsOneWidget);
    // 手动添加的条目也在列表顶部
    final firstTile = tester.widget<ListTile>(find.byType(ListTile).first);
    expect((firstTile.title as Text).data, '交通');
  });

  testWidgets('手动添加: 金额无效时提示且表单不关闭', (WidgetTester tester) async {
    await pumpApp(tester, apiWith(MockClient((_) async => jsonResponse(okBody(), 200))));

    await tester.tap(find.text('手动添加'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'abc');
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    expect(find.textContaining('金额无效'), findsOneWidget);
    expect(find.text('确认'), findsOneWidget); // 表单仍在
  });
}
