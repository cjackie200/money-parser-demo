# Flutter 记账解析页实现计划(已确认)

> 状态:已确认并实现(2026-11-11,commit `255cda2`)。工程目录 `./app`。
> 本阶段为纯 UI demo,不接网络;接真实接口的计划见后续文档。

## 目标

Flutter 单页:顶部输入框 + 解析按钮 + 假数据列表 + 手动添加备用入口,服务真实接口前的 UI 骨架。

## 技术选型

| 项 | 决定 |
|---|---|
| 工程 | `flutter create --org com.cjackie200 --project-name money_parser_app app` |
| SDK | Flutter 3.47.9 stable / Dart 3.13.7(用户本机原无 SDK,经官方国内镜像 `storage.flutter-io.cn` 安装到 `~/flutter`) |
| 依赖 | 零第三方包,只用官方 flutter + flutter_test |
| 状态管理 | StatefulWidget + setState(单页 demo,不引入 provider) |
| UI | Material 3,AppBar + TextField + ListView |

## 文件结构

```
app/lib/
├── main.dart        // runApp + MoneyParserApp(MaterialApp 壳)
├── entry.dart       // Entry 模型,字段对齐 docs/api_contract.md
└── parse_page.dart  // ParsePage 页面(StatefulWidget)
app/test/
└── widget_test.dart // widget 测试
```

## 关键组件签名

```dart
// entry.dart —— 字段与 docs/api_contract.md 契约一致
class Entry {
  final double amount;    // 金额
  final String category;  // 分类
  final String direction; // expense | income(契约字段,UI 暂不渲染)
  const Entry({required this.amount, required this.category, required this.direction});
  factory Entry.fromJson(Map<String, dynamic> json); // 为接真实接口预留
}

// parse_page.dart
class ParsePage extends StatefulWidget { const ParsePage({super.key}); ... }
class _ParsePageState extends State<ParsePage> {
  List<Entry> _entries = const []; // 初始为空
  void _handleParse() { setState(() => _entries = _fakeEntries); } // 不读输入框、不发网络
  void _handleManualAdd() { /* SnackBar「敬请期待」,纯占位 */ }
}
```

## UI 结构(自上而下)

1. AppBar:标题「记账解析」
2. TextField:hint「输入一句话记账，例如：午饭35打车22」
3. 「解析」FilledButton:点击后假数据填充列表
4. 「手动添加」OutlinedButton:解析按钮正下方常驻,不随列表滚动消失;点击弹 SnackBar「敬请期待」
5. ListView:渲染 entries,每项展示金额 + 分类;初始为空时显示空态「点击解析查看结果」

假数据(取自 api_contract 示例):

```dart
const _fakeEntries = [
  Entry(amount: 35.0, category: '餐饮', direction: 'expense'),
  Entry(amount: 22.5, category: '交通', direction: 'expense'),
];
```

## 测试计划(widget_test.dart)

| 用例 | 断言 |
|---|---|
| 初始渲染 | 列表为空、空态文案、hint 文案、手动添加按钮存在 |
| 点「解析」 | 列表出现 2 条假数据,金额与分类文案可见 |
| 点「手动添加」 | SnackBar「敬请期待」出现 |

## 决策记录

- 契约示例分类「出行」统一改为「交通」,与服务端 `server/prompt.go` 分类表一致
- Flutter SDK 由 Claude 自动安装(brew 下载慢,切换官方国内镜像)
- 手动添加按钮位置:解析按钮正下方常驻(用户未提出异议,按 plan 默认执行)

## 验证结果

`flutter test` 3/3 通过,`flutter analyze` 零问题。
