import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'secure_storage_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiClient apiClient;
  final SecureStorageService storageService;

  String? _token;
  String? _email;
  bool _isLoading = false;
  String? _error;

  AuthProvider({
    required this.apiClient,
    required this.storageService,
  });

  String? get token => _token;
  String? get email => _email;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _token != null;

  Future<void> initialize() async {
    _token = await storageService.getToken();
    _email = await storageService.getEmail();
    if (_token != null) {
      apiClient.setToken(_token!);
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await apiClient.login(email, password);
      _token = response.token;
      _email = email;
      apiClient.setToken(_token!);
      await storageService.saveToken(_token!);
      await storageService.saveEmail(email);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _token = null;
    _email = null;
    apiClient.clearToken();
    await storageService.clearAll();
    notifyListeners();
  }
}
