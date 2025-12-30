import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'websocket_service.dart';
import '../models/index.dart';

class EventsProvider extends ChangeNotifier {
  final ApiClient apiClient;

  Map<String, List<Event>> _eventsByCase = {};
  Map<String, WebSocketService?> _wssByCase = {};
  bool _isLoading = false;
  String? _error;

  EventsProvider({required this.apiClient});

  List<Event> getEvents(String caseId) => _eventsByCase[caseId] ?? [];
  WebSocketService? getWebSocketFor(String caseId) => _wssByCase[caseId];
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchEvents(String caseId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final events = await apiClient.getEvents(caseId);
      _eventsByCase[caseId] = events;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> connectWebSocket(String caseId, String token) async {
    try {
      final ws = WebSocketService(
        baseUrl: apiClient.baseUrl,
        token: token,
        caseId: caseId,
      );
      
      await ws.connect();
      _wssByCase[caseId] = ws;
      
      // Listen for real-time events
      ws.messages.listen((message) {
        print('EventsProvider received WebSocket message: $message');
        if (message['type'] == 'event' && message.containsKey('event')) {
          try {
            final eventData = message['event'] as Map<String, dynamic>;
            print('EventData type: ${eventData.runtimeType}');
            print('EventData keys: ${eventData.keys}');
            print('EventData: $eventData');
            
            final event = Event.fromJson(eventData);
            
            print('Successfully parsed event: ${event.type} (${event.eventId})');
            _eventsByCase[caseId] = [...(_eventsByCase[caseId] ?? []), event];
            notifyListeners();
          } catch (e) {
            print('Error parsing event from WebSocket: $e');
            print('Stack trace: $e');
          }
        } else if (message['type'] == 'connection') {
          print('WebSocket connection established: ${message['status']}');
        } else if (message['type'] == 'ping') {
          print('Received ping from server');
        } else {
          print('Received WebSocket message of type: ${message['type']}');
        }
      });
    } catch (e) {
      print('Error connecting WebSocket: $e');
      _error = 'WebSocket connection failed: $e';
      notifyListeners();
    }
  }

  void disconnectWebSocket(String caseId) {
    _wssByCase[caseId]?.disconnect();
    _wssByCase.remove(caseId);
  }

  void sendMessage(String caseId, Map<String, dynamic> message) {
    _wssByCase[caseId]?.send(message);
  }

  @override
  void dispose() {
    for (var ws in _wssByCase.values) {
      ws?.dispose();
    }
    super.dispose();
  }
}

