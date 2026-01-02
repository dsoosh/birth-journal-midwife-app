import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const String _tokenKey = 'auth_token';
const String _emailKey = 'auth_email';
const String _pinKey = 'auth_pin';
const String _sessionValidKey = 'session_valid_until';

class SecureStorageService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  Future<void> saveEmail(String email) async {
    await _storage.write(key: _emailKey, value: email);
  }

  Future<String?> getEmail() async {
    return await _storage.read(key: _emailKey);
  }

  Future<void> savePin(String pin) async {
    await _storage.write(key: _pinKey, value: pin);
  }

  Future<String?> getPin() async {
    return await _storage.read(key: _pinKey);
  }

  Future<bool> hasPin() async {
    final pin = await _storage.read(key: _pinKey);
    return pin != null && pin.isNotEmpty;
  }

  Future<void> saveSessionValidUntil(DateTime validUntil) async {
    await _storage.write(key: _sessionValidKey, value: validUntil.toIso8601String());
  }

  Future<DateTime?> getSessionValidUntil() async {
    final value = await _storage.read(key: _sessionValidKey);
    if (value == null) return null;
    return DateTime.parse(value);
  }

  Future<void> clearAll() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _pinKey);
    await _storage.delete(key: _sessionValidKey);
  }
}
