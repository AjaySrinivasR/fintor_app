// lib/providers/category_provider.dart
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/category_model.dart';

class CategoryProvider extends ChangeNotifier {
  final List<CategoryItem> _categories = [
    CategoryItem(
      id: '1',
      name: 'Food & Dining',
      icon: Icons.restaurant_rounded,
      color: const Color(0xFFEA580C),
      keywords: [
        'swiggy',
        'zomato',
        'blinkit',
        'zepto',
        'starbucks',
        'cafe',
        'mcdonalds',
        'kfc',
        'burger'
      ],
    ),
    CategoryItem(
      id: '2',
      name: 'Travel & Fuel',
      icon: Icons.directions_car_rounded,
      color: const Color(0xFF2563EB),
      keywords: [
        'uber',
        'ola',
        'fuel',
        'petrol',
        'hpcl',
        'bpcl',
        'ioc',
        'irctc',
        'metro',
        'rapido'
      ],
    ),
    CategoryItem(
      id: '3',
      name: 'Shopping',
      icon: Icons.shopping_bag_rounded,
      color: const Color(0xFFDB2777),
      keywords: [
        'amazon',
        'flipkart',
        'myntra',
        'ajio',
        'zara',
        'h&m',
        'mart',
        'retail'
      ],
    ),
    CategoryItem(
      id: '4',
      name: 'Entertainment',
      icon: Icons.movie_creation_rounded,
      color: const Color(0xFF7C3AED),
      keywords: [
        'netflix',
        'spotify',
        'hotstar',
        'prime',
        'pvr',
        'inox',
        'bookmyshow',
        'youtube'
      ],
    ),
    CategoryItem(
      id: '5',
      name: 'Utilities & Bills',
      icon: Icons.bolt_rounded,
      color: const Color(0xFF059669),
      keywords: [
        'airtel',
        'jio',
        'vi',
        'bescom',
        'tata play',
        'broadband',
        'electricity',
        'gas'
      ],
    ),
    CategoryItem(
      id: '6',
      name: 'Investments & SIP',
      icon: Icons.trending_up_rounded,
      color: const Color(0xFF0D9488),
      keywords: [
        'zerodha',
        'groww',
        'coin',
        'kuvera',
        'mutual fund',
        'sip',
        'upstox'
      ],
    ),
  ];

  List<CategoryItem> get categories => List.unmodifiable(_categories);

  String matchCategory(String merchantOrTitle) {
    final lower = merchantOrTitle.toLowerCase();
    for (final cat in _categories) {
      for (final kw in cat.keywords) {
        if (lower.contains(kw.toLowerCase())) {
          return cat.name;
        }
      }
    }
    return 'General';
  }

  void addCategory(
      String name, IconData icon, Color color, List<String> keywords) {
    _categories.add(CategoryItem(
      id: const Uuid().v4(),
      name: name,
      icon: icon,
      color: color,
      keywords: keywords,
    ));
    notifyListeners();
  }

  void addKeywordToCategory(String categoryId, String keyword) {
    final index = _categories.indexWhere((c) => c.id == categoryId);
    if (index != -1 &&
        !_categories[index].keywords.contains(keyword.toLowerCase())) {
      _categories[index].keywords.add(keyword.toLowerCase().trim());
      notifyListeners();
    }
  }

  void deleteCategory(String id) {
    _categories.removeWhere((c) => c.id == id);
    notifyListeners();
  }
}
