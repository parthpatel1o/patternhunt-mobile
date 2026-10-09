import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patternhunt_mobile/core/config/env.dart';
import 'package:patternhunt_mobile/features/auth/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MemoryPkceStorage extends GotrueAsyncStorage {
  final _values = <String, String>{};

  @override
  Future<String?> getItem({required String key}) async => _values[key];

  @override
  Future<void> setItem({required String key, required String value}) async {
    _values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    _values.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const launcher = MethodChannel('plugins.flutter.io/url_launcher');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUpAll(() async {
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-key',
      authOptions: FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: const EmptyLocalStorage(),
        pkceAsyncStorage: _MemoryPkceStorage(),
      ),
    );
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(launcher, null);
    debugDefaultTargetPlatformOverride = null;
  });

  tearDownAll(() async => Supabase.instance.dispose());

  Future<void> openLogin(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: LoginScreen())),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('Google sign-in uses the system browser on $platform', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = platform;
      MethodCall? launch;
      messenger.setMockMethodCallHandler(launcher, (call) async {
        launch = call;
        return true;
      });
      await openLogin(tester);
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(launch?.method, 'launch');
      final arguments = launch!.arguments as Map;
      // iOS's default launch mode opens Safari inside the app and leaves it
      // covering the authenticated screen. Neither embedded mode should be used.
      expect(arguments['useSafariVC'], isFalse);
      expect(arguments['useWebView'], isFalse);
      final url = Uri.parse(arguments['url'] as String);
      expect(url.queryParameters['provider'], 'google');
      expect(url.queryParameters['redirect_to'], Env.authRedirectUrl);
      expect(url.queryParameters['code_challenge'], isNotEmpty);
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    });
  }

  for (final throwsException in [false, true]) {
    testWidgets(
      'Google browser launch failure is shown (throws: $throwsException)',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        messenger.setMockMethodCallHandler(launcher, (_) async {
          if (throwsException) throw PlatformException(code: 'launch-failed');
          return false;
        });
        await openLogin(tester);
        await tester.tap(find.text('Continue with Google'));
        await tester.pumpAndSettle();

        expect(
          find.text('Could not open Google sign-in Please try again'),
          findsOneWidget,
        );
        final button = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'Continue with Google'),
        );
        expect(button.onPressed, isNotNull);
        expect(tester.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }
}
