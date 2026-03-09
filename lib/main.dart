
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/home_screen.dart';
import 'screens/verificador_recibo_screen.dart';
import 'screens/web_login_screen.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';
import 'package:url_strategy/url_strategy.dart'; 

import 'package:provider/provider.dart';
import 'providers/theme_provider.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';

// Import del nuevo servicio de suscripción
import 'subscription/subscription_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  setPathUrlStrategy(); 

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("No se pudo cargar el archivo .env: $e");
  }

  // Inicializar Supabase PRIMERO, ya que otros servicios dependen de él
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  // Ahora que Supabase está inicializado, podemos inicializar otros servicios
  await SubscriptionService.initialize();

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
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeProvider.themeMode,
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
        '/web-login': (context) => const WebLoginScreen(),
      },
      onGenerateRoute: (settings) {
        // NOTE: Se define `isAdminBypass` para evitar errores de compilación.
        // Se recomienda implementar una lógica de roles de usuario adecuada.
        const bool isAdminBypass = false; 

        final user = Supabase.instance.client.auth.currentUser;
        
        if (user == null && !isAdminBypass && settings.name != '/web-login') {
          return MaterialPageRoute(builder: (_) => const WebLoginScreen());
        }
        
        if (settings.name == '/home') {
           return MaterialPageRoute(builder: (_) => const HomeScreen());
        }
        if (settings.name == '/verificador') {
           return MaterialPageRoute(builder: (_) => const VerificadorReciboScreen());
        }

        return null;
      },
      home: const SplashScreen(),
    );
  }
}
