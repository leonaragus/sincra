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

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setPathUrlStrategy(); 

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("No se pudo cargar el archivo .env: $e");
  }

  // Inicializar Supabase con configuración hardcodeada (segura para anon key)
  // Esto permite que funcione sin .env en producción/web
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  FlutterError.onError = (FlutterErrorDetails details) => FlutterError.presentError(details);
  PlatformDispatcher.instance.onError = (error, stack) => true;

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
      routes: {
        '/home': (context) => const HomeScreen(),
        '/verificador': (context) => const VerificadorReciboScreen(),
        '/web-login': (context) => const WebLoginScreen(),
      },
      onGenerateRoute: (settings) {
        // Simple auth guard
        final user = Supabase.instance.client.auth.currentUser;
        if (user == null && settings.name != '/web-login') {
          return MaterialPageRoute(builder: (_) => const WebLoginScreen());
        }
        return null;
      },
      home: Builder(
        builder: (context) {
          final user = Supabase.instance.client.auth.currentUser;
          if (user == null) {
            return const WebLoginScreen();
          }
          return const HomeScreen();
        },
      ),
    );
  }
}
