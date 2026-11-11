import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'parse_api.dart';
import 'parse_page.dart';

void main() {
  runApp(MoneyParserApp());
}

/// 编译期环境变量(--dart-define=BASE_URL=...)优先;
/// 未设置时 Android 模拟器经 10.0.2.2 访问宿主机,其余用 localhost。
const String _envBaseUrl = String.fromEnvironment('BASE_URL');

String _defaultBaseUrl() {
  if (_envBaseUrl.isNotEmpty) {
    return _envBaseUrl;
  }
  if (kIsWeb) {
    return 'http://localhost:8080';
  }
  if (Platform.isAndroid) {
    return 'http://10.0.2.2:8080';
  }
  return 'http://localhost:8080';
}

/// 应用根组件。
class MoneyParserApp extends StatelessWidget {
  /// [api] 为 null 时按环境变量/平台默认值创建(初始器里创建一次,不在 build 里反复 new)。
  MoneyParserApp({super.key, ParseApi? api})
      : api = api ?? ParseApi(baseUrl: _defaultBaseUrl());

  final ParseApi api;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '记账解析',
      theme: ThemeData(colorSchemeSeed: Colors.teal),
      home: ParsePage(api: api),
    );
  }
}
