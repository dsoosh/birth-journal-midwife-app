import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'config/config.dart';
import 'l10n/app_localizations.dart';
import 'models/index.dart';
import 'screens/alerts_screen.dart';
import 'screens/case_detail_screen.dart';
import 'screens/cases_list_screen.dart';
import 'screens/login_screen.dart';
import 'services/alerts_provider.dart';
import 'services/api_client.dart';
import 'services/auth_provider.dart';
import 'services/cases_provider.dart';
import 'services/events_provider.dart';
import 'services/secure_storage_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notification service
  await NotificationService().initialize();

  final apiClient = ApiClient(baseUrl: Config.apiUrl);
  final storage = SecureStorageService();
  runApp(App(apiClient: apiClient, storageService: storage));
}

class App extends StatefulWidget {
  final ApiClient apiClient;
  final SecureStorageService storageService;

  const App({super.key, required this.apiClient, required this.storageService});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final AuthProvider _authProvider;
  late final LanguageProvider _languageProvider;
  late final Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _authProvider = AuthProvider(
      apiClient: widget.apiClient,
      storageService: widget.storageService,
    );
    _languageProvider = LanguageProvider();
    _initFuture = _authProvider.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: widget.apiClient),
        ChangeNotifierProvider<AuthProvider>.value(value: _authProvider),
        ChangeNotifierProvider<LanguageProvider>.value(
          value: _languageProvider,
        ),
        ChangeNotifierProvider(
          create: (_) => CasesProvider(apiClient: widget.apiClient),
        ),
        ChangeNotifierProvider(
          create: (_) => EventsProvider(apiClient: widget.apiClient),
        ),
        ChangeNotifierProvider(
          create: (_) => AlertsProvider(apiClient: widget.apiClient),
        ),
      ],
      child: Consumer<LanguageProvider>(
        builder: (context, langProvider, _) {
          return FutureBuilder<void>(
            future: _initFuture,
            builder: (context, snapshot) {
              return MaterialApp(
                title: 'Położne – Midwife Tools',
                locale: langProvider.locale,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: const [Locale('en'), Locale('pl')],
                theme: ThemeData(
                  colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
                  useMaterial3: true,
                ),
                routes: {
                  '/login': (_) => const LoginScreen(),
                  '/cases': (_) => const CasesListScreen(),
                  '/alerts': (_) => const AlertsScreen(),
                },
                onGenerateRoute: (settings) {
                  if (settings.name == '/case-detail') {
                    final caseArg = settings.arguments as Case;
                    return MaterialPageRoute(
                      builder: (_) => CaseDetailScreen(case_: caseArg),
                    );
                  }
                  return null;
                },
                home: _buildHome(snapshot),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHome(AsyncSnapshot<void> snapshot) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.isAuthenticated) {
          return const CasesListScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
