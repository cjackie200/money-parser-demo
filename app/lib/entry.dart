/// 记账条目模型,字段与 docs/api_contract.md 的服务端契约一致。
class Entry {
  /// 金额
  final double amount;

  /// 分类(固定分类表: 餐饮、购物、交通、居住、娱乐、医疗、教育、其他)
  final String category;

  /// 方向: expense 支出 | income 收入
  final String direction;

  const Entry({
    required this.amount,
    required this.category,
    required this.direction,
  });

  /// 从服务端 JSON 解析,为接入真实接口预留。
  factory Entry.fromJson(Map<String, dynamic> json) {
    return Entry(
      amount: (json['amount'] as num).toDouble(),
      category: json['category'] as String,
      direction: json['direction'] as String,
    );
  }
}
