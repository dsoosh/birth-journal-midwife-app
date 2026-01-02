import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/index.dart';

class CasesPage {
  final List<Case> cases;
  final String? nextCursor;
  final String? serverCursor;

  CasesPage({
    required this.cases,
    this.nextCursor,
    this.serverCursor,
  });
}

class CreateCaseResponse {
  final String caseId;
  final String joinCode;

  CreateCaseResponse({required this.caseId, required this.joinCode});

  factory CreateCaseResponse.fromJson(Map<String, dynamic> json) {
    return CreateCaseResponse(
      caseId: json['case_id'] ?? '',
      joinCode: json['join_code'] ?? '',
    );
  }
}

class ApiClient {
  final String baseUrl;
  String? _token;

  ApiClient({required this.baseUrl});

  void setToken(String token) {
    _token = token;
  }

  void clearToken() {
    _token = null;
  }

  Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
    };
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  Future<AuthResponse> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: _headers,
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      return AuthResponse.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Login failed: ${response.statusCode}');
    }
  }

  Future<AuthResponse> register(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: _headers,
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      return AuthResponse.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 409) {
      throw Exception('Email already exists');
    } else if (response.statusCode == 400) {
      throw Exception('Invalid input or password too short');
    } else {
      throw Exception('Registration failed: ${response.statusCode}');
    }
  }

  Future<CasesPage> getCasesWithCursor({
    String status = 'active',
    String view = 'summary',
    int limit = 50,
    String? cursor,
  }) async {
    final queryParams = {
      'status': status,
      'view': view,
      'limit': limit.toString(),
      if (cursor != null) 'cursor': cursor,
    };

    final response = await http.get(
      Uri.parse('$baseUrl/cases').replace(queryParameters: queryParams),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final casesList = (data['cases'] as List)
          .map((c) => Case.fromJson(c))
          .toList();
      return CasesPage(
        cases: casesList,
        nextCursor: data['next_cursor'],
        serverCursor: data['server_cursor'],
      );
    } else {
      throw Exception('Failed to get cases: ${response.statusCode}');
    }
  }

  Future<CreateCaseResponse> createCase() async {
    final response = await http.post(
      Uri.parse('$baseUrl/cases'),
      headers: _headers,
      body: jsonEncode({}),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return CreateCaseResponse.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create case: ${response.statusCode}');
    }
  }

  Future<String> claimCase(String joinCode) async {
    final response = await http.post(
      Uri.parse('$baseUrl/cases/claim'),
      headers: _headers,
      body: jsonEncode({'join_code': joinCode}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['case_id'];
    } else {
      throw Exception('Failed to claim case: ${response.statusCode}');
    }
  }

  Future<void> closeCase(String caseId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/cases/$caseId/close'),
      headers: _headers,
      body: jsonEncode({}),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to close case: ${response.statusCode}');
    }
  }

  Future<void> setLaborMode(String caseId, bool active) async {
    final response = await http.post(
      Uri.parse('$baseUrl/cases/$caseId/set-labor'),
      headers: _headers,
      body: jsonEncode({'active': active}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to set labor mode: ${response.statusCode}');
    }
  }

  Future<void> setPostpartumMode(String caseId, bool active) async {
    final response = await http.post(
      Uri.parse('$baseUrl/cases/$caseId/set-postpartum'),
      headers: _headers,
      body: jsonEncode({'active': active}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to set postpartum mode: ${response.statusCode}');
    }
  }

  Future<List<Event>> getEvents(
    String caseId, {
    int limit = 50,
    String? cursor,
  }) async {
    final queryParams = {
      'limit': limit.toString(),
      if (cursor != null) 'cursor': cursor,
    };

    final response = await http.get(
      Uri.parse('$baseUrl/cases/$caseId/events')
          .replace(queryParameters: queryParams),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final events = (data['events'] as List)
          .map((e) => Event.fromJson(e))
          .toList();
      return events;
    } else {
      throw Exception('Failed to get events: ${response.statusCode}');
    }
  }

  Future<List<Alert>> getAlerts({
    String status = 'active',
    int limit = 50,
    String? cursor,
  }) async {
    final queryParams = {
      'status': status,
      'limit': limit.toString(),
      if (cursor != null) 'cursor': cursor,
    };

    final response = await http.get(
      Uri.parse('$baseUrl/alerts')
          .replace(queryParameters: queryParams),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // Parse alerts - they are events with type 'alert_triggered'
      final alerts = (data['alerts'] as List)
          .map((a) {
            final event = Event.fromJson(a);
            final payload = event.payload;
            final explain = AlertExplain.fromJson(payload['explain'] ?? {});
            return Alert(
              event: event,
              alertCode: payload['alert_code'] ?? '',
              severity: payload['severity'] ?? 'info',
              explain: explain,
            );
          })
          .toList();
      return alerts;
    } else {
      throw Exception('Failed to get alerts: ${response.statusCode}');
    }
  }

  Future<void> acknowledgeAlert(String caseId, String alertEventId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/cases/$caseId/alerts/$alertEventId/ack'),
      headers: _headers,
      body: jsonEncode({}),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to acknowledge alert: ${response.statusCode}');
    }
  }

  Future<void> resolveAlert(String caseId, String alertEventId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/cases/$caseId/alerts/$alertEventId/resolve'),
      headers: _headers,
      body: jsonEncode({}),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to resolve alert: ${response.statusCode}');
    }
  }
}
