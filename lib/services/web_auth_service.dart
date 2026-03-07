import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:realtime_client/realtime_client.dart';

/// Servicio para gestionar la lógica de autenticación web a través de Supabase Realtime.
///
/// Encapsula la creación, suscripción y comunicación a través de canales
/// para el login por QR y por código manual.
class WebAuthService {
  final SupabaseClient _client = Supabase.instance.client;
  RealtimeChannel? _activeChannel;
  Timer? _timeoutTimer;

  /// Para la Web: Escucha un token de sesión a través de un ID de canal (obtenido por QR).
  void listenForQrSession({
    required String channelId,
    required void Function(String token) onTokenReceived,
  }) {
    _cleanup(); // Asegura que no haya canales previos activos.
    _activeChannel = _client.channel('web-login-$channelId');
    
    _activeChannel!.onBroadcast(
      event: 'session-token',
      callback: (payload) {
        final String? receivedToken = payload['token'];
        if (receivedToken != null) {
          onTokenReceived(receivedToken);
          _cleanup();
        }
      },
    );

    _activeChannel!.subscribe();
  }

  /// Para la Web: Solicita un token de sesión usando un código manual.
  void requestTokenWithManualCode({
    required String code,
    required void Function(String token) onTokenReceived,
    required void Function() onTimeout,
  }) {
    _cleanup();
    final channelName = 'manual-login-$code';
    _activeChannel = _client.channel(channelName);

    _activeChannel!.onBroadcast(
      event: 'session-token',
      callback: (payload) {
        final String? receivedToken = payload['token'];
        if (receivedToken != null) {
          onTokenReceived(receivedToken);
          _cleanup();
        }
      },
    );

    _activeChannel!.subscribe((status, [e]) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        // Una vez suscrito, pide el token al dispositivo móvil.
        await _activeChannel!.send(
          type: 'broadcast' as dynamic,
          event: 'request-token',
          payload: {},
        );
      }
    });

    // Establece un timeout para la operación.
    _timeoutTimer = Timer(const Duration(seconds: 20), () {
      onTimeout();
      _cleanup();
    });
  }

  /// Para el Móvil: Envía la sesión actual a la web después de escanear un QR.
  Future<void> sendSessionToWeb(String channelId) async {
    final session = _client.auth.currentSession;
    if (session?.refreshToken == null) {
      throw Exception('No hay una sesión activa para enviar.');
    }

    final channel = _client.channel('web-login-$channelId');
    
    // Este canal es de corta duración: suscribir, enviar y cerrar.
    channel.subscribe((status, [_]) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        final token = _client.auth.currentSession?.refreshToken;
        if (token != null) {
          await channel.send(
            type: 'broadcast' as dynamic,
            event: 'session-token',
            payload: {'token': token},
          );
        }
        await channel.unsubscribe();
      }
    });
  }

  /// Para el Móvil: Genera un código y espera una solicitud de la web.
  /// Devuelve el código generado para que la UI lo muestre.
  Future<String> listenForManualCodeRequest({
    required void Function() onTokenSent,
  }) async {
    _cleanup();
    final code = (100000 + DateTime.now().millisecond % 900000).toString();
    final channelName = 'manual-login-$code';
    _activeChannel = _client.channel(channelName);
    
    _activeChannel!.onBroadcast(
      event: 'request-token',
      callback: (payload) async {
        final token = _client.auth.currentSession?.refreshToken;
        if (token != null) {
          await _activeChannel!.send(
            type: 'broadcast' as dynamic,
            event: 'session-token',
            payload: {'token': token},
          );
          onTokenSent(); // Notifica a la UI que el token fue enviado.
        }
        _cleanup();
      },
    );

    await _activeChannel!.subscribe();

    // Establece un timeout para el canal de escucha.
    _timeoutTimer = Timer(const Duration(minutes: 3), _cleanup);

    return code;
  }

  /// Cierra y limpia el canal y el temporizador activos para prevenir fugas de memoria.
  /// Debe ser llamado desde el `dispose()` del widget que lo usa.
  void dispose() {
    _cleanup();
  }

  void _cleanup() {
    _timeoutTimer?.cancel();
    _activeChannel?.unsubscribe();
    _timeoutTimer = null;
    _activeChannel = null;
  }
}
