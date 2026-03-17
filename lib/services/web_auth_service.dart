import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Servicio para gestionar la lógica de autenticación web a través de Supabase Realtime.
class WebAuthService {
  final SupabaseClient _client = Supabase.instance.client;
  RealtimeChannel? _activeChannel;
  Timer? _timeoutTimer;

  void listenForQrSession({
    required String channelId,
    required void Function(String token) onTokenReceived,
  }) {
    _cleanup();
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
      if (status == 'SUBSCRIBED') {
        await _activeChannel!.send(
          type: 'broadcast' as dynamic, 
          event: 'request-token', 
          payload: {},
        );
      }
    });

    _timeoutTimer = Timer(const Duration(seconds: 20), () {
      onTimeout();
      _cleanup();
    });
  }

  Future<void> sendTokenToChannel({
    required String channelId,
    required String token,
  }) async {
    final channel = _client.channel('web-login-$channelId');
    
    // Nos suscribimos y enviamos el token por broadcast
    await channel.subscribe((status, [e]) async {
      if (status == 'SUBSCRIBED') {
        await channel.send(
          type: 'broadcast' as dynamic,
          event: 'session-token',
          payload: {'token': token},
        );
      }
    });
    
    // Esperamos un momento para asegurar el envío antes de limpiar
    await Future.delayed(const Duration(seconds: 2));
  }

  Future<void> sendSessionToWeb(String channelId) async {
    final session = _client.auth.currentSession;
    final refreshToken = session?.refreshToken;
    if (refreshToken == null) {
      throw Exception('No hay una sesión activa para enviar.');
    }

    final channel = _client.channel('web-login-$channelId');
    
    channel.subscribe((status, [_]) async {
      if (status == 'SUBSCRIBED') {
        await channel.send(
          type: 'broadcast' as dynamic, 
          event: 'session-token', 
          payload: {'token': refreshToken},
        );
        await channel.unsubscribe();
      }
    });
  }

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
        final session = _client.auth.currentSession;
        if (session != null && session.refreshToken != null) {
          await _activeChannel!.send(
            type: 'broadcast' as dynamic, 
            event: 'session-token', 
            payload: {'token': session.refreshToken!},
          );
          onTokenSent();
        }
        _cleanup();
      },
    );

    await _activeChannel!.subscribe();
    _timeoutTimer = Timer(const Duration(minutes: 3), _cleanup);

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
