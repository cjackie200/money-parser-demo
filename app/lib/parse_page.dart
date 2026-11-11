import 'package:flutter/material.dart';

import 'entry.dart';

/// 假数据,与 docs/api_contract.md 成功示例一致。
/// 页面不接网络,「解析」按钮固定填充这份数据。
const List<Entry> _fakeEntries = [
  Entry(amount: 35.0, category: '餐饮', direction: 'expense'),
  Entry(amount: 22.5, category: '交通', direction: 'expense'),
];

/// 记账解析页。
class ParsePage extends StatefulWidget {
  const ParsePage({super.key});

  @override
  State<ParsePage> createState() => _ParsePageState();
}

class _ParsePageState extends State<ParsePage> {
  final TextEditingController _controller = TextEditingController();

  /// 解析结果,初始为空。
  List<Entry> _entries = const [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 不读输入框、不发网络,固定填充假数据。
  void _handleParse() {
    setState(() {
      _entries = _fakeEntries;
    });
  }

  /// 备用入口,当前仅占位提示。
  void _handleManualAdd() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('敬请期待')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('记账解析')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: '输入一句话记账，例如：午饭35打车22',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _handleParse,
                child: const Text('解析'),
              ),
            ),
            const SizedBox(height: 8),
            // 「手动添加」备用入口,始终保留
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _handleManualAdd,
                child: const Text('手动添加'),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _entries.isEmpty
                  ? const Center(child: Text('点击解析查看结果'))
                  : ListView.builder(
                      itemCount: _entries.length,
                      itemBuilder: (context, index) {
                        final entry = _entries[index];
                        return Card(
                          child: ListTile(
                            title: Text(entry.category),
                            trailing: Text('¥${entry.amount}'),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
