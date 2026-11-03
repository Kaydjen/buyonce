import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'core/theme/app_theme.dart';
import 'data/services/firebase_account_service.dart';
import 'data/services/firebase_group_service.dart';
import 'data/services/firebase_list_service.dart';
import 'data/services/firebase_user_service.dart';
import 'data/services/service_providers.dart';
import 'domain/models/app_settings.dart';
import 'presentation/view_models/settings/style_variant_view_model.dart';
import 'presentation/view_models/settings/settings_view_model.dart';
import 'presentation/screens/app_gate.dart';

// Web client id from google-services.json (client_type 3); not a secret.
const _serverClientId =
    '548461971411-fvv7f3ukkvduf26lahoouku616ibih8a.apps.googleusercontent.com';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await GoogleSignIn.instance.initialize(serverClientId: _serverClientId);
  // The page runs under the system bars; the screens keep their own safe areas.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(
    ProviderScope(
      overrides: [
        realAccountServiceProvider.overrideWithValue(FirebaseAccountService()),
        realGroupServiceProvider.overrideWithValue(FirebaseGroupService()),
        realListServiceProvider.overrideWithValue(FirebaseListService()),
        realUserServiceProvider.overrideWithValue(FirebaseUserService()),
      ],
      child: const BuyOnceApp(),
    ),
  );
}

class BuyOnceApp extends ConsumerWidget {
  const BuyOnceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final variant = ref.watch(styleVariantProvider);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BuyOnce',
      theme: AppTheme.light(variant),
      darkTheme: AppTheme.dark(variant),
      themeMode: switch (ref.watch(settingsProvider.select((s) => s.theme))) {
        ThemeChoice.system => ThemeMode.system,
        ThemeChoice.light => ThemeMode.light,
        ThemeChoice.dark => ThemeMode.dark,
      },
      builder: (context, child) {
        // The one place the text size is set: a fixed choice replaces the phone's own.
        final factor = ref
            .watch(settingsProvider.select((s) => s.textScale))
            .factor;
        return MediaQuery(
          data: factor == null
              ? MediaQuery.of(context)
              : MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(factor)),
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            // The bars are transparent, so the page runs under them to the edges.
            value:
                (Theme.of(context).brightness == Brightness.dark
                        ? SystemUiOverlayStyle.light
                        : SystemUiOverlayStyle.dark)
                    .copyWith(
                      statusBarColor: const Color(0x00000000),
                      systemStatusBarContrastEnforced: false,
                      systemNavigationBarColor: const Color(0x00000000),
                      systemNavigationBarDividerColor: const Color(0x00000000),
                      systemNavigationBarIconBrightness:
                          Theme.of(context).brightness == Brightness.dark
                          ? Brightness.light
                          : Brightness.dark,
                      systemNavigationBarContrastEnforced: false,
                    ),
            child: child!,
          ),
        );
      },
      home: const AppGate(),
    );
  }
}
