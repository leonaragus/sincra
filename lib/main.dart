import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/home_screen.dart';
import 'screens/verificador_recibo_screen.dart';
import 'screens/web_login_screen.dart';
import 'theme/app_theme.dart';
import 'package:url_strategy/url_strategy.dart'; // Import agregado

import 'package:provider/provider.dart';
import 'providers/theme_provider.dart';
import 'screens/plan_selection_screen.dart'; // Import restaurado
import 'config/supabase_config.dart';

void main() {
  setPathUrlStrategy(); // Función agregada aquí

  FlutterError.onError = (FlutterErrorDetails details) => FlutterError.presentError(details);
  PlatformDispatcher.instance.onError = (error, stack) => true;

  WidgetsFlutterBinding.ensureInitialized();
  Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
    authOptions: const FlutterAuthClientOptions(
      autoRefreshToken: true,
    ),
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light, // Tema claro
      darkTheme: AppTheme.dark, // Tema oscuro
      themeMode: themeProvider.themeMode, // Modo dinámico
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
      home: WebAuthGate(child: const HomeScreen()),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/verificador': (context) => const VerificadorReciboScreen(),
        '/web-login': (context) => const WebLoginScreen(),
        '/plans': (context) => const PlanSelectionScreen(),
      },
    );
  }
}
