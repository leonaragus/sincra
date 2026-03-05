
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:realtime_client/realtime_client.dart';

// Credenciales de prueba
const String supabaseUrl = 'https://sstxhajsclwfktyvawmr.supabase.co';
const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNzdHhoYWpzY2x3Zmt0eXZhd21yIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MTk1MTAzNDQsImV4cCI6MjAzNTA4NjM0NH0.j-n_1y4g2W_Fop2cQ_pCHiS7h-EW3p_6o3o6I5iAFNA';

void main() {
  setUpAll(() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  });

  test('Prueba Final y Correcta del Flujo de Login', () async {
    final supabase = Supabase.instance.client;
    final completer = Completer<String>();
    const mockRefreshToken = 'the-truly-final-token';
    final channelId = const Uuid().v4();
    final channelName = 'web-login-$channelId';

    // 1. WEB: Escuchar por el token usando onBroadcast con callback
    final webChannel = supabase.channel(channelName);

    webChannel.onBroadcast(
      event: 'session-token',
      callback: (payload) {
        final receivedToken = payload['token'] as String?;
        print('Web: Token recibido: "$receivedToken"');
        if (receivedToken != null && !completer.isCompleted) {
          completer.complete(receivedToken);
        }
      },
    );

    await webChannel.subscribe();
    print('Web: Suscrito y escuchando en $channelName');

    // Se necesita una pequeña pausa para asegurar que la suscripción esté activa en el servidor
    await Future.delayed(const Duration(seconds: 2));

    // 2. MÓVIL: Enviar el token usando send con el parámetro type
    final mobileChannel = supabase.channel(channelName);
    await mobileChannel.subscribe();
    print('Móvil: Suscrito al canal $channelName para enviar.');

    print('Móvil: Enviando token...');
    await mobileChannel.send(
      type: RealtimeListenTypes.broadcast,
      event: 'session-token',
      payload: {'token': mockRefreshToken},
    );
    print('Móvil: Token enviado.');

    // 3. VERIFICACIÓN
    final result = await completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => 'TIMEOUT',
    );

    expect(result, mockRefreshToken, reason: 'El flujo de comunicación falló con la sintaxis onBroadcast/send.');

    print('\n✅ ¡ÉXITO! La prueba con la sintaxis correcta ha pasado.');

    // Limpieza
    await webChannel.unsubscribe();
    await mobileChannel.unsubscribe();
  });
}
