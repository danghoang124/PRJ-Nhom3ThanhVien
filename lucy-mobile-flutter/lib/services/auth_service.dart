import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  final String authServerUrl;

  AuthService({required this.authServerUrl});

  String? _token;
  String? _email;
  String? _role;

  String? get token => _token;
  String? get email => _email;
  String? get role => _role;
  bool get isLoggedIn => _token != null;

  /// Đăng ký tài khoản mới
  Future<String?> register(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$authServerUrl/api/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _token = data['token'];
        _email = data['email'];
        _role = data['role'];
        return null; // success
      } else {
        final err = json.decode(response.body);
        return err['message'] ?? 'Đăng ký thất bại';
      }
    } catch (e) {
      return 'Không kết nối được server Auth';
    }
  }

  /// Đăng nhập
  Future<String?> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$authServerUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _token = data['token'];
        _email = data['email'];
        _role = data['role'];
        return null; // success
      } else {
        final err = json.decode(response.body);
        return err['message'] ?? 'Đăng nhập thất bại';
      }
    } catch (e) {
      return 'Không kết nối được server Auth';
    }
  }

  /// Đăng xuất
  void logout() {
    _token = null;
    _email = null;
    _role = null;
  }

  /// Get auth headers for API calls
  Map<String, String> get authHeaders {
    if (_token == null) return {};
    return {'Authorization': 'Bearer $_token'};
  }
}
