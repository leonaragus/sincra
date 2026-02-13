import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/home_screen.dart';
import 'screens/verificador_recibo_screen.dart';
import 'screens/web_login_screen.dart';
import 'theme/app_theme.dart';
import 'package:url_strategy/url_strategy.dart'; // Import agregado

import 'package:provider/provider.dart';
import 'providers/theme_provider.dart';
import 'screens/plan_selection_screen.dart'; // Import restaurado

import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'services/web_link_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

void main() async {
  setPathUrlStrategy(); // Función agregada aquí

  FlutterError.onError = (FlutterErrorDetails details) => FlutterError.presentError(details);
  PlatformDispatcher.instance.onError = (error, stack) => true;

  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Supabase
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  // Inicializar servicio de vinculación web
  await WebLinkService.init();

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
    
    // Si es web y no hay sesión activa ni bypass, forzamos login
    final bool showWebLogin = kIsWeb && 
        Supabase.instance.client.auth.currentSession == null && 
        !WebLinkService.isBypassed;

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
      home: showWebLogin ? const WebLoginScreen() : const HomeScreen(),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/verificador': (context) => const VerificadorReciboScreen(),
        '/web-login': (context) => const WebLoginScreen(),
        '/plans': (context) => const PlanSelectionScreen(),
      },
    );
  }
}
