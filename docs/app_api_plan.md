# 「解析」按钮接 POST /api/parse 实现计划(已确认)

> 状态:已确认(2026-11-11)。在 `docs/app_plan.md` 的 UI 骨架基础上接入真实接口。

## 目标

「解析」按钮调用 `POST /api/parse`,loading 防重复、成功替换列表、失败红色 SnackBar 且手动入口始终可见、任何异常不红屏。

## 技术选型

| 项 | 决定 |
|---|---|
| HTTP 客户端 | `http` 包(官方,自带 `MockClient` 可测试) |
| baseUrl | `--dart-define=BASE_URL=...` 优先;未设置时平台兜底:Android → `http://10.0.2.2:8080`,其他 → `http://localhost:8080` |
| 客户端超时 | 10s(服务端 8s + 余量),可注入便于测试 |

## 文件结构

```
app/lib/
├── main.dart         // 改动: 装配 baseUrl → ParseApi → ParsePage
├── entry.dart        // 不变
├── parse_api.dart    // 新增: HTTP 调用 + ParseException
└── parse_page.dart   // 改动: _handleParse 改为调用 api
app/test/
├── widget_test.dart  // 重写: MockClient 驱动
└── parse_api_test.dart // 新增: 纯 Dart 单测
```

## 关键签名

```dart
// parse_api.dart
class ParseException implements Exception {
  final String message; // 用户可读中文文案
}

class ParseApi {
  ParseApi({required String baseUrl, http.Client? client,
            Duration timeout = const Duration(seconds: 10)});
  // 内部: baseUrl 去尾部斜杠;失败全部包装为 ParseException(裸 catch 兜 TypeError 等)
  Future<List<Entry>> parse(String text);
}

// main.dart
String _defaultBaseUrl(); // kIsWeb 守卫 → Platform.isAndroid 兜底;BASE_URL 优先

class MoneyParserApp extends StatelessWidget {
  MoneyParserApp({super.key, ParseApi? api})
      : api = api ?? ParseApi(baseUrl: _defaultBaseUrl()); // 初始器创建一次
  final ParseApi api;
}

// parse_page.dart
class ParsePage extends StatefulWidget {
  const ParsePage({super.key, required this.api});
  final ParseApi api;
}
class _ParsePageState ... {
  bool _loading = false;
  Future<void> _handleParse(); // 首行 if (_loading) return 防同帧双击
  void _showErrorSnackBar(String message); // 红底,弹前 hideCurrentSnackBar
}
```

## 行为流程

- **点击**:`_loading=true` → 按钮 `onPressed=null` + 按钮内 CircularProgressIndicator(双保险防重复)
- **200**:`utf8.decode(bodyBytes)` → `jsonDecode` → 取 `entries` → 替换 ListView;空数组显示空态
- **4xx/5xx**:红底 SnackBar,优先后端 `errors[0]`,否则 `解析失败 (HTTP xxx)`
- **超时/SocketException/ClientException**:红底 SnackBar「连接超时,请检查服务是否启动」
- **兜底**:`ParseApi` 裸 catch 包装一切异常(含 TypeError);页面 catch 后 `mounted` 检查再 setState/弹条,`finally` 复位 loading

## 平台配置(明文 HTTP 必需)

- Android 主 manifest:加 `INTERNET` 权限 + `android:usesCleartextTraffic="true"`
- iOS `Info.plist`:`NSAppTransportSecurity → NSAllowsLocalNetworking=true`

## 测试计划

### parse_api_test.dart(纯 Dart,MockClient + 短超时注入)

| 用例 | 断言 |
|---|---|
| 200 正常 JSON | POST `{base}/api/parse`、body `{"text":...}`、entries 映射正确 |
| 500 带 errors | ParseException,文案 = 后端 errors[0] |
| 400 无 errors 字段 | ParseException,文案 `解析失败 (HTTP 400)` |
| 200 但 body 非法 JSON / entries 缺失 / amount 为字符串 | 均 ParseException(TypeError 被裸 catch 接住) |
| 超时(handler 延迟 > 注入超时) | ParseException「连接超时,请检查服务是否启动」 |
| 网络异常(handler 抛 ClientException) | 同上 |

### widget_test.dart(MockClient 注入)

| 用例 | 断言 |
|---|---|
| 初始渲染 | hint、解析、手动添加、空态,无 ListView |
| 200 成功 | 金额/分类文案可见,空态消失,loading 消失 |
| 加载中 | ProgressIndicator 可见,FilledButton onPressed 为 null |
| 防重复:重建后二击 | 计数 = 1(验证按钮禁用) |
| 防重复:同帧双击(tap→tap 不 pump) | 计数 = 1(验证回调 guard) |
| 500 | 红色 SnackBar(断言 backgroundColor==Colors.red)+「手动添加」仍可见 |
| 网络异常 | 红色 SnackBar「连接超时」+「手动添加」仍可见 |
| 手动添加点击 | SnackBar「敬请期待」(保留原测试) |

## 决策记录

- 空文本也发请求,由服务端 400 兜底(客户端不加预校验)
- 200 且 entries 为空:显示空态,errors 内容本轮不展示
- 错误文案:优先后端 errors[0];超时/网络统一「连接超时,请检查服务是否启动」;未知兜底「解析失败,请稍后重试」
- 保留 openai-go 默认重试(服务端),客户端 10s 超时覆盖最坏情况
