import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/auth/auth_controller.dart';
import 'features/auth/login_page.dart';
import 'features/household/current_household_provider.dart';
import 'features/household/household_setup_page.dart';
import 'features/main/main_page.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'core/theme/theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeSettings = ref.watch(themeControllerProvider);

    return MaterialApp(
      title: 'SplitLedger',
      debugShowCheckedModeBanner: false,
      themeMode: themeSettings.themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: themeSettings.accentColor.color,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        popupMenuTheme: PopupMenuThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          iconColor: themeSettings.accentColor.color,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: themeSettings.accentColor.color,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        popupMenuTheme: PopupMenuThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          iconColor: themeSettings.accentColor.color,
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);

    return authState.when(
      data: (user) {
        if (user == null) return const LoginPage();

        final householdAsync = ref.watch(currentHouseholdProvider);
        return householdAsync.when(
          data: (household) => household == null
              ? const HouseholdSetupPage()
              : const MainPage(),
          loading: () => const _SplashScreen(),
          error: (err, _) => _ErrorScreen(message: err.toString()),
        );
      },
      loading: () => const _SplashScreen(),
      error: (err, _) => const LoginPage(),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorScreen extends ConsumerWidget {
  final String message;

  const _ErrorScreen({required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Something went wrong', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => ref.read(authControllerProvider).signOut(),
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
