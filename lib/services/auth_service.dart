import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class AuthService {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'jwt_token';

  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  static Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
  }

  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    final url = Uri.parse('${ApiService.baseUrl}/auth/login');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['token'] != null) {
      await saveToken(data['token']);
      return {'success': true, 'token': data['token']};
    }
    return {'success': false, 'message': data['message'] ?? 'Login failed'};
  }

  static Future<Map<String, dynamic>> register(
      String name, String email, String password) async {
    final url = Uri.parse('${ApiService.baseUrl}/auth/register');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 201 && data['token'] != null) {
      await saveToken(data['token']);
      return {'success': true, 'token': data['token']};
    }
    return {
      'success': false,
      'message': data['message'] ?? 'Registration failed'
    };
  }
}
