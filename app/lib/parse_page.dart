import 'package:flutter/material.dart';

import 'entry.dart';
import 'parse_api.dart';

/// 记账解析页。
class ParsePage extends StatefulWidget {
  const ParsePage({super.key, required this.api});

  final ParseApi api;

  @override
  State<ParsePage> createState() => _ParsePageState();
}

class _ParsePageState extends State<ParsePage> {
  final TextEditingController _controller = TextEditingController();

  /// 解析结果,初始为空。
  List<Entry> _entries = const [];

  /// 请求进行中,用于防重复点击。
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 调用后端解析。防重复、失败红色 SnackBar、手动入口不受影响。
  Future<void> _handleParse() async {
    if (_loading) return; // 同帧双击兜底(onPressed 禁用要等下一帧才生效)

    setState(() => _loading = true);
    try {
      final entries = await widget.api.parse(_controller.text);
      if (!mounted) return;
      setState(() => _entries = entries);
    } catch (e) {
      if (!mounted) return;
      final message = e is ParseException ? e.message : '解析失败，请稍后重试';
      _showErrorSnackBar(message);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  /// 备用入口,当前仅占位提示。
  void _handleManualAdd() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('敬请期待')),
    );
  }

  /// 失败提示: 红底,弹前清掉旧条避免堆叠。
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(message),
        ),
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
                onPressed: _loading ? null : _handleParse,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('解析'),
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
