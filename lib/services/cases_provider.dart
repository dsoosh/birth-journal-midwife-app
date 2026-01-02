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
      final result = await apiClient.getCasesWithCursor(
        cursor: clearExisting ? null : _nextCursor,
      );
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

  Future<bool> setLaborMode(String caseId, bool active) async {
    try {
      await apiClient.setLaborMode(caseId, active);
      // Update local case
      final index = _cases.indexWhere((c) => c.caseId == caseId);
      if (index != -1) {
        final c = _cases[index];
        _cases[index] = Case(
          caseId: c.caseId,
          label: c.label,
          laborActive: active,
          postpartumActive: active ? false : c.postpartumActive,
          lastEventTs: DateTime.now(),
          activeAlerts: c.activeAlerts,
        );
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> setPostpartumMode(String caseId, bool active) async {
    try {
      await apiClient.setPostpartumMode(caseId, active);
      // Update local case
      final index = _cases.indexWhere((c) => c.caseId == caseId);
      if (index != -1) {
        final c = _cases[index];
        _cases[index] = Case(
          caseId: c.caseId,
          label: c.label,
          laborActive: active ? false : c.laborActive,
          postpartumActive: active,
          lastEventTs: DateTime.now(),
          activeAlerts: c.activeAlerts,
        );
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Case? getCaseById(String caseId) {
    try {
      return _cases.firstWhere((c) => c.caseId == caseId);
    } catch (_) {
      return null;
    }
  }
}
