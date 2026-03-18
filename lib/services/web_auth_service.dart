import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;

/// Servicio para gestionar la lógica de autenticación web a través de Supabase Realtime.
class WebAuthService {
  final SupabaseClient _client = Supabase.instance.client;
  RealtimeChannel? _activeChannel;
  Timer? _timeoutTimer;

  /// Escucha el token de sesión en la web (QR).
  void listenForQrSession({
    required String channelId,
    required void Function(String token) onTokenReceived,
  }) {
    _cleanup();
    final channel = _client.channel('web-login-$channelId');
    _activeChannel = channel;
    
    channel.onBroadcast(
      event: 'session-token',
      callback: (payload) async {
        final String? receivedToken = payload['token'];
        if (receivedToken != null) {
          // ENVIAR ACK AL MÓVIL
          await channel.send(
            type: 'broadcast' as dynamic,
            event: 'session-received',
            payload: {},
          );
          onTokenReceived(receivedToken);
          _cleanup();
        }
      },
    );

    channel.subscribe((status, [e]) {
      debugPrint('Supabase Web QR: $status');
    });
  }

  /// Solicita el token usando un código manual (Web -> Mobile).
  void requestTokenWithManualCode({
    required String code,
    required void Function(String token) onTokenReceived,
    required void Function() onTimeout,
  }) {
    _cleanup();
    final channelName = 'manual-login-$code';
    final channel = _client.channel(channelName);
    _activeChannel = channel;

    bool tokenReceived = false;

    channel.onBroadcast(
      event: 'session-token',
      callback: (payload) async {
        final String? receivedToken = payload['token'];
        if (receivedToken != null && !tokenReceived) {
          tokenReceived = true;
          // ENVIAR ACK AL MÓVIL
          await channel.send(
            type: 'broadcast' as dynamic,
            event: 'session-received',
            payload: {},
          );
          onTokenReceived(receivedToken);
          _cleanup();
        }
      },
    );

    channel.subscribe((status, [e]) async {
      if (status == 'SUBSCRIBED') {
        // Reintentar la solicitud cada 2 segundos hasta recibir el token o timeout
        for (int i = 0; i < 10; i++) {
          if (tokenReceived) break;
          await channel.send(
            type: 'broadcast' as dynamic, 
            event: 'request-token', 
            payload: {},
          );
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    });

    _timeoutTimer = Timer(const Duration(seconds: 30), () {
      if (!tokenReceived) {
        onTimeout();
        _cleanup();
      }
    });
  }

  /// Envía el token de sesión actual al canal de la web con reintentos y confirmación (ACK).
  Future<void> sendTokenToChannelWithAck({
    required String channelId,
    required String token,
  }) async {
    final channel = _client.channel('web-login-$channelId');
    final completer = Completer<void>();
    bool ackReceived = false;
    int retryCount = 0;
    const maxRetries = 10; // Más reintentos para mayor seguridad

    // Escuchar el ACK de la web
    channel.onBroadcast(
      event: 'session-received',
      callback: (payload) {
        ackReceived = true;
        if (!completer.isCompleted) completer.complete();
      },
    );

    await channel.subscribe((status, [e]) async {
      if (status == 'SUBSCRIBED') {
        // Enviar el token periódicamente hasta recibir el ACK o agotar reintentos
        while (!ackReceived && retryCount < maxRetries) {
          await channel.send(
            type: 'broadcast' as dynamic,
            event: 'session-token',
            payload: {'token': token},
          );
          
          retryCount++;
          await Future.delayed(const Duration(milliseconds: 800));
        }

        if (!ackReceived && !completer.isCompleted) {
          completer.completeError(Exception('La PC no respondió. Verifica que la web esté abierta en el QR.'));
        }
      } else if (status == 'CHANNEL_ERROR' || status == 'TIMED_OUT') {
        if (!completer.isCompleted) completer.completeError(Exception('Fallo de conexión con el servidor de Supabase.'));
      }
    });

    try {
      return await completer.future.timeout(const Duration(seconds: 15));
    } finally {
      _client.removeChannel(channel);
    }
  }

  /// Escucha solicitudes de código manual (Mobile -> Web).
  Future<String> listenForManualCodeRequest({
    required void Function() onTokenSent,
  }) async {
    _cleanup();
    // Código de 6 dígitos basado en el tiempo para que sea único pero corto
    final code = (100000 + (DateTime.now().millisecondsSinceEpoch % 900000)).toString();
    final channelName = 'manual-login-$code';
    final channel = _client.channel(channelName);
    _activeChannel = channel;
    
    bool tokenSent = false;

    channel.onBroadcast(
      event: 'request-token',
      callback: (payload) async {
        if (tokenSent) return;
        
        final session = _client.auth.currentSession;
        if (session != null && session.refreshToken != null) {
          // Al recibir solicitud, enviamos el token. 
          // No limpiamos el canal aquí todavía, esperamos el ACK de la web.
          await channel.send(
            type: 'broadcast' as dynamic, 
            event: 'session-token', 
            payload: {'token': session.refreshToken!},
          );
        }
      },
    );

    // Escuchar el ACK de la web para el código manual
    channel.onBroadcast(
      event: 'session-received',
      callback: (payload) {
        tokenSent = true;
        onTokenSent();
        _cleanup();
      },
    );

    await channel.subscribe();
    _timeoutTimer = Timer(const Duration(minutes: 5), _cleanup);

    return code;
  }

  void dispose() {
    _cleanup();
  }

  void _cleanup() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    if (_activeChannel != null) {
      _client.removeChannel(_activeChannel!);
      _activeChannel = null;
    }
  }
}
