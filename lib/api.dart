import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Change at build time: flutter build apk --dart-define=API_BASE=https://yourdomain.com/api/v1/
const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'https://erp.powerkothi.in/power/power-kothi/api/v1/');
const String appVersion = '1.0.0';

class ApiError implements Exception {
  final String message;
  final int code;
  ApiError(this.message, this.code);
  @override
  String toString() => message;
}

class Api {
  static late SharedPreferences prefs;
  static String? token;
  static Map<String, dynamic>? user;
  static Map<String, dynamic> config = {};
  static Map<String, dynamic> masters = {};

  static Future<void> init() async {
    prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token');
    final u = prefs.getString('user');
    if (u != null) user = jsonDecode(u) as Map<String, dynamic>;
  }

  static bool get loggedIn => token != null;

  static Future<void> saveLogin(String t, Map<String, dynamic> u) async {
    token = t;
    await saveUser(u);
    await prefs.setString('token', t);
  }

  static Future<void> saveUser(Map<String, dynamic> u) async {
    user = u;
    await prefs.setString('user', jsonEncode(u));
  }

  static Future<void> logout() async {
    token = null;
    user = null;
    await prefs.remove('token');
    await prefs.remove('user');
  }

  static Map<String, String> _headers([bool json = false]) => {
        if (json) 'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  static dynamic _read(http.Response r) {
    Map<String, dynamic> b;
    try {
      b = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw ApiError('The server sent an unexpected reply. Try again.', r.statusCode);
    }
    if (b['ok'] == true) return b['data'];
    if (r.statusCode == 401 && token != null) logout();
    throw ApiError('${b['error'] ?? 'Something went wrong.'}', r.statusCode);
  }

  static Uri _uri(String path, [Map<String, dynamic>? q]) {
    final clean = <String, String>{};
    q?.forEach((k, v) {
      if (v != null && '$v'.isNotEmpty) clean[k] = '$v';
    });
    return Uri.parse('$apiBase$path').replace(queryParameters: clean.isEmpty ? null : clean);
  }

  static Future<T> _guard<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on ApiError {
      rethrow;
    } catch (_) {
      throw ApiError('No connection. Check your internet and try again.', 0);
    }
  }

  static Future<dynamic> get(String path, [Map<String, dynamic>? q]) =>
      _guard(() async => _read(await http.get(_uri(path, q), headers: _headers()).timeout(const Duration(seconds: 25))));

  static Future<dynamic> post(String path, [Map<String, dynamic>? body]) =>
      _guard(() async => _read(await http.post(_uri(path), headers: _headers(true), body: jsonEncode(body ?? {})).timeout(const Duration(seconds: 25))));

  static Future<dynamic> put(String path, Map<String, dynamic> body) =>
      _guard(() async => _read(await http.put(_uri(path), headers: _headers(true), body: jsonEncode(body)).timeout(const Duration(seconds: 25))));

  static Future<dynamic> delete(String path) =>
      _guard(() async => _read(await http.delete(_uri(path), headers: _headers()).timeout(const Duration(seconds: 25))));

  static Future<dynamic> upload(String path, Map<String, String> fields, Map<String, String> files) => _guard(() async {
        final req = http.MultipartRequest('POST', _uri(path))
          ..headers.addAll(_headers())
          ..fields.addAll(fields);
        for (final e in files.entries) {
          req.files.add(await http.MultipartFile.fromPath(e.key, e.value));
        }
        final res = await req.send().timeout(const Duration(seconds: 60));
        return _read(await http.Response.fromStream(res));
      });
}
