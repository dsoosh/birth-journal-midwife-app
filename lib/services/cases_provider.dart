import 'package:flutter/foundation.dart';
import 'api_client.dart';
import '../models/index.dart';

class CasesProvider extends ChangeNotifier {
  final ApiClient apiClient;

  List<Case> _cases = [];
  bool _isLoading = false;
  String? _error;
  String? _nextCursor;

  CasesProvider({required this.apiClient});

  List<Case> get cases => _cases;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasMore => _nextCursor != null;

  Future<void> fetchCases({bool clearExisting = true}) async {
    _isLoading = true;
    _error = null;
    if (clearExisting) {
      _cases = [];
      _nextCursor = null;
    }
    notifyListeners();

    try {
      final result = await apiClient.getCasesWithCursor(cursor: clearExisting ? null : _nextCursor);
      final cases = result.cases;
      _nextCursor = result.nextCursor;

      if (clearExisting) {
        _cases = cases;
      } else {
        _cases.addAll(cases);
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createCase() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await apiClient.createCase();
      await fetchCases();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> closeCase(String caseId) async {
    try {
      await apiClient.closeCase(caseId);
      _cases.removeWhere((c) => c.caseId == caseId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}
