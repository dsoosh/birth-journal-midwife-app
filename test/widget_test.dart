// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:birth_journal_midwife/main.dart';
import 'package:birth_journal_midwife/services/api_client.dart';
import 'package:birth_journal_midwife/services/secure_storage_service.dart';

void main() {
  testWidgets('App smoke test - loads without crashing', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    final apiClient = ApiClient(baseUrl: 'http://localhost:8000/api/v1');
    final storage = SecureStorageService();
    
    await tester.pumpWidget(App(
      apiClient: apiClient,
      storageService: storage,
    ));

    // Initially should show loading indicator while initializing
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    
    // Let a few frames pass for initialization
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    
    // App should have loaded MaterialApp
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
