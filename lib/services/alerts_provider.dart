import 'package:flutter/foundation.dart';
import 'api_client.dart';
import '../models/index.dart';

class AlertsProvider extends ChangeNotifier {
  final ApiClient apiClient;

  List<Alert> _alerts = [];
  bool _isLoading = false;
  String? _error;

  AlertsProvider({required this.apiClient});

  List<Alert> get alerts => _alerts;
  List<Alert> get activeAlerts => _alerts.where((a) => a.isActive).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchAlerts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final alerts = await apiClient.getAlerts();
      _alerts = alerts;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> acknowledgeAlert(String caseId, String alertEventId) async {
    try {
      await apiClient.acknowledgeAlert(caseId, alertEventId);
      // Remove from local alerts
      _alerts.removeWhere((a) => a.event.eventId == alertEventId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> resolveAlert(String caseId, String alertEventId) async {
    try {
      await apiClient.resolveAlert(caseId, alertEventId);
      // Remove from local alerts
      _alerts.removeWhere((a) => a.event.eventId == alertEventId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}
