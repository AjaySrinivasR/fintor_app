// lib/models/category_model.dart
import 'package:flutter/material.dart';

class CategoryItem {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final List<String> keywords;

  CategoryItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.keywords,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'iconCode': icon.codePoint,
        'colorValue': color.value,
        'keywords': keywords,
      };

  factory CategoryItem.fromJson(Map<String, dynamic> json) => CategoryItem(
        id: json['id'] ?? '',
        name: json['name'] ?? 'General',
        icon: IconData(json['iconCode'] ?? Icons.category.codePoint,
            fontFamily: 'MaterialIcons'),
        color: Color(json['colorValue'] ?? 0xFF1E3A8A),
        keywords: List<String>.from(json['keywords'] ?? []),
      );
}
