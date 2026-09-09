class CategoryBudget {
  final String id;
  final String category;
  final double limitAmount;
  final String monthYear;

  CategoryBudget({
    required this.id,
    required this.category,
    required this.limitAmount,
    required this.monthYear,
  });

  factory CategoryBudget.fromJson(Map<String, dynamic> json) => CategoryBudget(
        id: json['id'] ?? json['_id'] ?? '',
        category: json['category'] ?? 'General',
        limitAmount: (json['limitAmount'] as num?)?.toDouble() ?? 0.0,
        monthYear: json['monthYear'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'limitAmount': limitAmount,
        'monthYear': monthYear,
      };
}
