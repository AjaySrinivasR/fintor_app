import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/database_helper.dart';
import '../services/api_service.dart';

class UserProvider extends ChangeNotifier {
  double _monthlyIncome = 50000.0;
  double _liquidReserves = 100000.0;
  String _riskProfile = 'conservative';
  String? _jwtToken;

  double get monthlyIncome => _monthlyIncome;
  double get liquidReserves => _liquidReserves;
  String get riskProfile => _riskProfile;

  void setAuthToken(String token) {
    _jwtToken = token;
    fetchRemoteProfile();
  }

  Future<void> loadLocalProfile() async {
    final profile = await DatabaseHelper.instance.getUserProfile();
    _monthlyIncome = (profile['monthly_income'] as num).toDouble();
    _liquidReserves = (profile['liquid_reserves'] as num).toDouble();
    _riskProfile = profile['risk_profile'] as String? ?? 'conservative';
    notifyListeners();
  }

  Future<void> updateFinancialParameters({
    required double monthlyIncome,
    required double liquidReserves,
  }) async {
    _monthlyIncome = monthlyIncome;
    _liquidReserves = liquidReserves;
    notifyListeners();

    // 1. Commit to SQLite
    await DatabaseHelper.instance.saveUserProfile(
      monthlyIncome: monthlyIncome,
      liquidReserves: liquidReserves,
      riskProfile: _riskProfile,
    );

    // 2. Sync to Backend
    if (_jwtToken != null) {
      try {
        await http.put(
          Uri.parse('${ApiService.baseUrl}/user/profile'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_jwtToken',
          },
          body: jsonEncode({
            'monthlyIncome': monthlyIncome,
            'liquidReserves': liquidReserves,
          }),
        );
      } catch (_) {
        // Retain offline state in SQLite
      }
    }
  }

  Future<void> fetchRemoteProfile() async {
    if (_jwtToken == null) return;
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/user/profile'),
        headers: {'Authorization': 'Bearer $_jwtToken'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'];
        _monthlyIncome = (data['monthlyIncome'] as num).toDouble();
        _liquidReserves = (data['liquidReserves'] as num).toDouble();
        _riskProfile = data['riskProfile'] ?? 'conservative';

        await DatabaseHelper.instance.saveUserProfile(
          monthlyIncome: _monthlyIncome,
          liquidReserves: _liquidReserves,
          riskProfile: _riskProfile,
        );
        notifyListeners();
      }
    } catch (_) {
      // Fallback to local SQLite values
    }
  }
}
