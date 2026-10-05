import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Thin HTTP client for the self-hosted backend (see /backend in the repo).
///
/// Replaces direct `FirebaseFirestore`/`FirebaseAuth` calls throughout the
/// app. Holds the JWT issued by `/auth/login` or `/auth/guest` and attaches
/// it as `Authorization: Bearer <token>` on every request.
///
/// IMPORTANT: set [baseUrl] to your VPS's actual address before shipping
/// (e.g. `https://api.yourdomain.com`). Using plain `http://` in production
/// will fail on Android/iOS due to App Transport Security / cleartext
/// traffic restrictions — always deploy the backend behind HTTPS.
class ApiClient {
  ApiClient._internal();
  static final ApiClient instance = ApiClient._internal();

  /// Change this to your deployed backend URL.
  static const String baseUrl = 'https://api.yourdomain.com';

  static const _tokenKey = 'auth_jwt_token';

  String? _cachedToken;

  Future<String?> get token async {
    if (_cachedToken != null) return _cachedToken;
    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString(_tokenKey);
    return _cachedToken;
  }

  Future<void> setToken(String token) async {
    _cachedToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> clearToken() async {
    _cachedToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  /// Reads the logged-in user's Mongo ID out of the JWT payload. This is a
  /// plain base64 decode (not a verified/trusted read) — fine for local UI
  /// decisions like "which side of this chat room am I", never for
  /// anything security-sensitive (the server always re-verifies the token).
  Future<String?> get currentUserId async {
    final t = await token;
    if (t == null) return null;
    final parts = t.split('.');
    if (parts.length != 3) return null;
    try {
      var payload = parts[1];
      payload += '=' * ((4 - payload.length % 4) % 4); // pad base64
      final decoded = utf8.decode(base64Url.decode(payload));
      final map = jsonDecode(decoded) as Map<String, dynamic>;
      return map['uid']?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, String>> _headers({bool withAuth = true}) async {
    final headers = {'Content-Type': 'application/json'};
    if (withAuth) {
      final t = await token;
      if (t != null) headers['Authorization'] = 'Bearer $t';
    }
    return headers;
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    return Uri.parse('$baseUrl$path').replace(
      queryParameters: query?.map((k, v) => MapEntry(k, v.toString())),
    );
  }

  /// Parses a response into a Map, throwing [ApiException] on non-2xx codes.
  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      body = {'success': false, 'message': 'Invalid server response'};
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        statusCode: response.statusCode,
        message: body['message']?.toString() ?? 'Request failed (${response.statusCode})',
      );
    }
    return body;
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query, bool withAuth = true}) async {
    final response = await http.get(_uri(path, query), headers: await _headers(withAuth: withAuth));
    return _decode(response);
  }

  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? body, bool withAuth = true}) async {
    final response = await http.post(
      _uri(path),
      headers: await _headers(withAuth: withAuth),
      body: jsonEncode(body ?? {}),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> put(String path, {Map<String, dynamic>? body, bool withAuth = true}) async {
    final response = await http.put(
      _uri(path),
      headers: await _headers(withAuth: withAuth),
      body: jsonEncode(body ?? {}),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> delete(String path, {bool withAuth = true}) async {
    final response = await http.delete(_uri(path), headers: await _headers(withAuth: withAuth));
    return _decode(response);
  }

  /// Uploads a file as multipart/form-data (e.g. a profile image). [field]
  /// is the form field name the backend's multer middleware expects.
  Future<Map<String, dynamic>> uploadFile(
    String path, {
    required String field,
    required List<int> bytes,
    required String filename,
    bool withAuth = true,
  }) async {
    final request = http.MultipartRequest('POST', _uri(path));
    final headers = await _headers(withAuth: withAuth);
    headers.remove('Content-Type'); // let http set the multipart boundary itself
    request.headers.addAll(headers);
    request.files.add(http.MultipartFile.fromBytes(field, bytes, filename: filename));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return _decode(response);
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException({required this.statusCode, required this.message});

  @override
  String toString() => message;
}
