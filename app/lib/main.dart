import 'package:flutter/material.dart';

import 'parse_page.dart';

void main() {
  runApp(const MoneyParserApp());
}

/// 应用根组件。
class MoneyParserApp extends StatelessWidget {
  const MoneyParserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '记账解析',
      theme: ThemeData(colorSchemeSeed: Colors.teal),
      home: const ParsePage(),
    );
  }
}
