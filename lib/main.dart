import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/env.dart';
import 'config/routes.dart';
import 'providers/location_provider.dart';
import 'providers/theme_provider.dart';
import 'services/secure_local_storage.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  // All async startup work — including the runApp call — must execute inside
  // runZonedGuarded so any uncaught Dart errors are captured by Sentry.
  await runZonedGuarded(_bootstrap, (error, stack) {
    Sentry.captureException(error, stackTrace: stack);
  });
}

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  Env.assertConfigured();

  // Forward Flutter framework errors to Sentry, then keep default console
  // logging in debug builds.
  FlutterError.onError = (details) {
    Sentry.captureException(details.exception, stackTrace: details.stack);
    if (kDebugMode) FlutterError.presentError(details);
  };

  // Async/platform errors that escape Dart zones (e.g. thrown from a callback
  // registered with the engine) are routed here.
  PlatformDispatcher.instance.onError = (error, stack) {
    Sentry.captureException(error, stackTrace: stack);
    return true;
  };

  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
    authOptions: FlutterAuthClientOptions(
      localStorage: SecureLocalStorage(),
    ),
  );

  if (Env.sentryDsn.isNotEmpty) {
    await SentryFlutter.init((options) {
      options.dsn = Env.sentryDsn;
      options.environment = Env.sentryEnvironment;
      options.tracesSampleRate = 0.2;
      options.attachStacktrace = true;
      options.sendDefaultPii = false;
    }, appRunner: () => runApp(const ProviderScope(child: BlackDogApp())));
  } else {
    runApp(const ProviderScope(child: BlackDogApp()));
  }
}

class BlackDogApp extends ConsumerStatefulWidget {
  const BlackDogApp({super.key});

  @override
  ConsumerState<BlackDogApp> createState() => _BlackDogAppState();
}

class _BlackDogAppState extends ConsumerState<BlackDogApp> {
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        final router = ref.read(routerProvider);
        router.go('/reset-password');
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Trigger location permission request on app start
    ref.watch(userLocationProvider);

    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Black Dog Panamá',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
