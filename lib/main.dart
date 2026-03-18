import 'package:flutter/foundation.dart' show kIsWeb;
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

// ESTE ES TU CÓDIGO AZUL (CLIENT ID)
const String googleClientId = '651720319688-7cmbf72enhg4t52q3rdc0tni4459u9ed.apps.googleusercontent.com';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  setPathUrlStrategy(); 

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("No se pudo cargar el archivo .env: $e");
  }

  // Inicializar Supabase de la manera más directa posible
  try {
    const String supabaseUrl = 'https://sstxhajsclwfktyvawmr.supabase.co';
    const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNzdHhoYWpzY2x3Zmt0eXZhd21yIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MTk1MTAzNDQsImV4cCI6MjAzNTA4NjM0NH0.j-n_1y4g2W_Fop2cQ_pCHiS7h-EW3p_6o3o6I5iAFNA';
    
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      debug: true,
    );
    debugPrint("Supabase listo.");
  } catch (e) {
    debugPrint("Error crítico Supabase: $e");
  }

  // Ahora que Supabase está inicializado, podemos inicializar otros servicios
  if (!kIsWeb) {
    try {
      await SubscriptionService.initialize();
    } catch (e) {
      debugPrint("Error al inicializar suscripciones: $e");
    }
  }

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
        // Permitimos que SplashScreen siempre sea el punto de entrada
        if (settings.name == '/') {
          return MaterialPageRoute(builder: (_) => const SplashScreen());
        }

        final user = Supabase.instance.client.auth.currentUser;
        
        // Si estamos en la web y el usuario no está logueado, redirigir a la pantalla de login
        if (kIsWeb && user == null && settings.name != '/web-login') {
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
