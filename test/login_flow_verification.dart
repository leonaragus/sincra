
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:realtime_client/realtime_client.dart';

const String supabaseUrl = 'https://sstxhajsclwfktyvawmr.supabase.co';
const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNzdHhoYWpzY2x3Zmt0eXZhd21yIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MTk1MTAzNDQsImV4cCI6MjAzNTA4NjM0NH0.j-n_1y4g2W_Fop2cQ_pCHiS7h-EW3p_6o3o6I5iAFNA';

void main() {
  // NO USAR TestWidgetsFlutterBinding.ensureInitialized(); ROMPE LAS LLAMADAS DE RED.

  setUpAll(() async {
    // ESTA es la forma correcta de mockear SharedPreferences en un test unitario.
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  });

  test('La Prueba Final, sin network mocks y con la suscripción correcta', () async {
    final supabase = Supabase.instance.client;
    final messageCompleter = Completer<String>();
    const mockRefreshToken = 'el-token-de-la-victoria-final';
    final channelName = 'web-login-${const Uuid().v4()}';

    final channel = supabase.channel(channelName);

    channel.onBroadcast(
      event: 'session-token',
      callback: (payload) {
        if (!messageCompleter.isCompleted) {
          messageCompleter.complete(payload['token'] as String);
        }
      },
    );

    final subscriptionCompleter = Completer<void>();
    channel.subscribe((status, [error]) {
      if (status == 'SUBSCRIBED') {
        if (!subscriptionCompleter.isCompleted) subscriptionCompleter.complete();
      }
    });
    
    // Esperamos a que la red REALMENTE nos confirme la suscripción
    await subscriptionCompleter.future.timeout(const Duration(seconds: 10));

    // Enviamos el mensaje
    await channel.send(
      type: RealtimeListenTypes.broadcast,
      event: 'session-token',
      payload: {'token': mockRefreshToken},
    );

    // Verificamos
    final result = await messageCompleter.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => 'TIMEOUT',
    );

    expect(result, mockRefreshToken);

    print('LA PRUEBA HA PASADO. EL PROBLEMA ESTÁ RESUELTO.');

    await channel.unsubscribe();
  });
}
