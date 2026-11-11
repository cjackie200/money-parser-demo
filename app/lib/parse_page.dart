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

  /// 记账列表,解析结果与手动添加的条目都累计在这里。
  List<Entry> _entries = const [];

  /// 请求进行中,用于防重复点击。
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 调用后端解析,成功时新条目**插到列表顶部**,不覆盖已有条目。
  Future<void> _handleParse() async {
    if (_loading) return; // 同帧双击兜底(onPressed 禁用要等下一帧才生效)

    setState(() => _loading = true);
    try {
      final entries = await widget.api.parse(_controller.text);
      if (!mounted) return;
      setState(() => _entries = [...entries, ..._entries]);
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

  /// 手动添加: 弹出底部表单,确认后条目追加到列表(纯本地,不调服务端)。
  Future<void> _handleManualAdd() async {
    final entry = await showModalBottomSheet<Entry>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _ManualAddSheet(),
    );
    if (entry != null && mounted) {
      // 新增条目插到列表顶部
      setState(() => _entries = [entry, ..._entries]);
    }
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

/// 手动添加底部表单: 金额 + 分类 + 方向。
class _ManualAddSheet extends StatefulWidget {
  const _ManualAddSheet();

  @override
  State<_ManualAddSheet> createState() => _ManualAddSheetState();
}

class _ManualAddSheetState extends State<_ManualAddSheet> {
  final TextEditingController _amountController = TextEditingController();

  String _category = kCategories.first;
  bool _isExpense = true;
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  /// 校验金额并提交,合法则关闭表单返回 Entry。
  void _submit() {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = '金额无效，请输入大于 0 的数字');
      return;
    }
    Navigator.of(context).pop(Entry(
      amount: amount,
      category: _category,
      direction: _isExpense ? 'expense' : 'income',
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 键盘弹出时表单上移
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('手动添加',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: '金额',
                  errorText: _error,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: '分类',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final c in kCategories)
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (v) => setState(() => _category = v ?? _category),
              ),
              const SizedBox(height: 12),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('支出')),
                  ButtonSegment(value: false, label: Text('收入')),
                ],
                selected: {_isExpense},
                onSelectionChanged: (s) => setState(() => _isExpense = s.first),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _submit, child: const Text('确认')),
            ],
          ),
        ),
      ),
    );
  }
}
