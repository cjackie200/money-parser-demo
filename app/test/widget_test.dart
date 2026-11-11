import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_parser_app/main.dart';

void main() {
  testWidgets('初始渲染: hint、解析按钮、手动添加按钮、空态文案', (WidgetTester tester) async {
    await tester.pumpWidget(const MoneyParserApp());

    expect(find.text('输入一句话记账，例如：午饭35打车22'), findsOneWidget);
    expect(find.text('解析'), findsOneWidget);
    expect(find.text('手动添加'), findsOneWidget);
    expect(find.text('点击解析查看结果'), findsOneWidget);
    expect(find.byType(ListView), findsNothing);
  });

  testWidgets('点解析后列表填充假数据', (WidgetTester tester) async {
    await tester.pumpWidget(const MoneyParserApp());

    await tester.tap(find.text('解析'));
    await tester.pump();

    expect(find.text('点击解析查看结果'), findsNothing);
    expect(find.text('餐饮'), findsOneWidget);
    expect(find.text('交通'), findsOneWidget);
    expect(find.text('¥35.0'), findsOneWidget);
    expect(find.text('¥22.5'), findsOneWidget);
  });

  testWidgets('点手动添加出现 SnackBar 占位提示', (WidgetTester tester) async {
    await tester.pumpWidget(const MoneyParserApp());

    await tester.tap(find.text('手动添加'));
    await tester.pump();

    expect(find.text('敬请期待'), findsOneWidget);
  });
}
