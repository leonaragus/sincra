import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:syncra_arg/config/supabase_config.dart';
import 'package:syncra_arg/services/web_auth_service.dart';

void main() {
  group('WebAuthService E2E', () {
    setUpAll(() async {
      // Mockear SharedPreferences para evitar MissingPluginException en tests
      SharedPreferences.setMockInitialValues({});
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
        // Sin opciones especiales: queremos minimizar acoples a la UI
      );
    });

    tearDownAll(() async {
      await Supabase.instance.client.auth.signOut();
    });

    test('Handshake QR con ACK funciona end-to-end', () async {
      final web = WebAuthService();
      final mobile = WebAuthService();
      final channelId = const Uuid().v4();
      final tokenCompleter = Completer<String>();

      web.listenForQrSession(
        channelId: channelId,
        onTokenReceived: (token) => tokenCompleter.complete(token),
      );

      const tokenToSend = 'dummyRefreshToken-qr';
      await mobile.sendTokenToChannelWithAck(
        channelId: channelId,
        token: tokenToSend,
      );

      final received = await tokenCompleter.future
          .timeout(const Duration(seconds: 20));
      expect(received, isNotEmpty);

      web.dispose();
      mobile.dispose();
    });

    test('Código manual solicita y recibe token con ACK', () async {
      final mobile = WebAuthService();
      final web = WebAuthService();

      final ackCompleter = Completer<void>();
      final code = await mobile.listenForManualCodeRequest(
        onTokenSent: () => ackCompleter.complete(),
        testToken: 'dummyRefreshToken-manual',
      );

      final tokenCompleter = Completer<String>();
      web.requestTokenWithManualCode(
        code: code,
        onTokenReceived: (token) => tokenCompleter.complete(token),
        onTimeout: () => tokenCompleter.completeError(
          Exception('timeout esperando token'),
        ),
      );

      await ackCompleter.future.timeout(const Duration(seconds: 30));
      final received = await tokenCompleter.future
          .timeout(const Duration(seconds: 30));
      expect(received, isNotEmpty);

      mobile.dispose();
      web.dispose();
    });
  });
}
