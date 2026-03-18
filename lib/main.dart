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

  // Inicializar Supabase PRIMERO, ya que otros servicios dependen de él
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  // Cargar el estado del bypass de administrador
  await loadAdminBypass();

  // Ahora que Supabase está inicializado, podemos inicializar otros servicios
  if (!kIsWeb) {
    try {
      await SubscriptionService.initialize();
    } catch (e) {
      debugPrint("Error al inicializar suscripciones: $e");
    }
  }

  // Desactivar temporalmente el manejo de errores agresivo para ver qué pasa en consola si falla algo
  // FlutterError.onError = (FlutterErrorDetails details) => FlutterError.presentError(details);
  // PlatformDispatcher.instance.onError = (error, stack) => true;

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
        
        // El bypass de administrador se chequea PRIMERO.
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
