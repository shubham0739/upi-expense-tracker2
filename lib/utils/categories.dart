import 'package:flutter/material.dart';

/// A spending category with a display icon and color.
class CategoryInfo {
  final String name;
  final IconData icon;
  final Color color;

  const CategoryInfo(this.name, this.icon, this.color);
}

/// Built-in categories shipped with the app.
const List<CategoryInfo> defaultCategories = [
  CategoryInfo('Food', Icons.restaurant, Color(0xFFF57C00)),
  CategoryInfo('Groceries', Icons.shopping_cart, Color(0xFF43A047)),
  CategoryInfo('Travel', Icons.directions_car, Color(0xFF1E88E5)),
  CategoryInfo('Shopping', Icons.shopping_bag, Color(0xFF8E24AA)),
  CategoryInfo('Rent', Icons.home, Color(0xFFE53935)),
  CategoryInfo('Bills', Icons.receipt_long, Color(0xFF00897B)),
  CategoryInfo('Health', Icons.favorite, Color(0xFFD81B60)),
  CategoryInfo('Entertainment', Icons.movie, Color(0xFF3949AB)),
  CategoryInfo('Education', Icons.school, Color(0xFF6D4C41)),
  CategoryInfo('Other', Icons.category, Color(0xFF607D8B)),
];

/// Color palette offered when the user creates a custom category.
const List<Color> customCategoryPalette = [
  Color(0xFFF57C00),
  Color(0xFF8E24AA),
  Color(0xFF00897B),
  Color(0xFFD81B60),
  Color(0xFF6D4C41),
  Color(0xFF3949AB),
  Color(0xFF00ACC1),
  Color(0xFFFFB300),
];

const Map<String, List<String>> _keywords = {
  'Food': [
    'zomato', 'swiggy', 'dominos', 'mcdonald', 'kfc', 'pizza', 'biryani',
    'restaurant', 'cafe', 'coffee', 'chai', 'food', 'dhaba', 'eatfit',
    'burger', 'rolls', 'baskin', 'momos', 'hotel',
  ],
  'Groceries': [
    'bigbasket', 'dmart', 'reliance', 'grocery', 'kirana', 'jiomart',
    'jio mart', 'blinkit', 'zepto', 'instamart', 'supermarket', 'vegetable',
    'milk', 'bbdaily',
  ],
  'Travel': [
    'uber', 'ola', 'rapido', 'irctc', 'petrol', 'fuel', 'metro', 'bus',
    'auto', 'cab', 'redbus', 'makemytrip', 'indigo', 'air india', 'toll',
    'parking', 'yatri',
  ],
  'Shopping': [
    'amazon', 'flipkart', 'myntra', 'ajio', 'meesho', 'nykaa', 'shop',
    'clothes', 'lifestyle', 'croma', 'vijay sales', 'decathlon',
  ],
  'Rent': ['rent', 'landlord', 'pg', 'hostel', 'lease', 'property'],
  'Bills': [
    'electricity', 'water', 'wifi', 'broadband', 'jio fiber', 'airtel',
    'vodafone', 'vi', 'bsnl', 'gas', 'dth', 'tata play', 'insurance',
    'lic', 'recharge', 'mobile', 'billdesk', 'tneb', 'adani', 'msedcl',
  ],
  'Health': [
    'apollo', 'medplus', 'pharmacy', 'hospital', 'clinic', 'doctor', 'gym',
    'cult', 'medic', 'netmeds', 'pharmeasy', 'lab',
  ],
  'Entertainment': [
    'netflix', 'spotify', 'hotstar', 'prime', 'steam', 'playstation',
    'bookmyshow', 'pvr', 'inox', 'youtube', 'gaming', 'movie',
  ],
  'Education': [
    'school', 'college', 'tuition', 'course', 'udemy', 'byjus',
    'unacademy', 'coursera', 'fees', 'exam',
  ],
};

/// Suggests a category from the payee name / SMS text using keywords.
String inferCategory(String text) {
  final t = text.toLowerCase();
  for (final entry in _keywords.entries) {
    if (entry.value.any(t.contains)) return entry.key;
  }
  return 'Other';
}
