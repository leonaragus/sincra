import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/user_type_selection_screen.dart';
import 'screens/verificador_recibos_screen.dart';
import 'screens/web_login_screen.dart';
import 'theme/app_theme.dart';
import 'package:url_strategy/url_strategy.dart'; // Import agregado

void main() {
  setPathUrlStrategy(); // Función agregada aquí

  FlutterError.onError = (FlutterErrorDetails details) => FlutterError.presentError(details);
  PlatformDispatcher.instance.onError = (error, stack) => true;

  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'AR'),
        Locale('en'),
      ],
      locale: const Locale('es', 'AR'),
      home: const SplashScreen(),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/verificador': (context) => const VerificadorRecibosScreen(),
        '/web-login': (context) => const WebLoginScreen(),
      },
    );
  }
}
