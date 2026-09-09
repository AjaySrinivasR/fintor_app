import 'dart:io' show Platform;
import 'package:fintor/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'core/dynamic_sms_parser.dart';
import 'providers/budget_provider.dart';
import 'providers/expense_provider.dart';
import 'providers/category_provider.dart';
import 'providers/subscription_provider.dart';
import 'services/auth_service.dart';
import 'services/biometric_service.dart';
import 'services/notification_remainder_service.dart';
import 'views/auth/auth_screen.dart';
import 'views/home_nav_scaffold.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final token = await AuthService.getToken();
  final expenseProvider = ExpenseProvider();
  await expenseProvider.loadLocalExpenses();

  final userProvider = UserProvider();
  await userProvider.loadLocalProfile();

  if (token != null) {
    expenseProvider.setAuthToken(token);
    userProvider.setAuthToken(token);
  }

  // 3. Fetch remote bank SMS regex patterns asynchronously
  DynamicSmsEngine.fetchRemoteTemplates();

  // 4. Check biometric requirement if logged in
  bool isAuthenticatedWithBiometrics = false;
  if (token != null) {
    isAuthenticatedWithBiometrics = await BiometricService.authenticate();
  }

  // 5. Initialize notification reminders & listener
  await NotificationReminderService.init();
  final categoryProvider = CategoryProvider();
  await expenseProvider.initializeNotificationListener(categoryProvider);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: expenseProvider),
        ChangeNotifierProvider(create: (_) => BudgetProvider()),
        ChangeNotifierProvider.value(value: categoryProvider),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
        ChangeNotifierProvider.value(value: userProvider),
      ],
      child: FintorApp(
        initialToken: token,
        isBiometricVerified: isAuthenticatedWithBiometrics,
      ),
    ),
  );
}

class FintorApp extends StatelessWidget {
  final String? initialToken;
  final bool isBiometricVerified;

  const FintorApp({
    super.key,
    this.initialToken,
    this.isBiometricVerified = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool canAccessHome = initialToken != null && isBiometricVerified;

    return MaterialApp(
      title: 'Fintor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E3A8A),
          primary: const Color(0xFF1E3A8A),
          surface: const Color(0xFFF8FAFC),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF0F172A),
          elevation: 0,
          scrolledUnderElevation: 1,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
      ),
      home: canAccessHome ? const HomeNavScaffold() : const AuthScreen(),
      // In lib/main.dart, temporarily bypass auth by setting home directly:
      // home: const HomeNavScaffold(),
    );
  }
}
