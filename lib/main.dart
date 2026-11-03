import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'core/theme/app_theme.dart';
import 'data/services/firebase_account_service.dart';
import 'data/services/firebase_group_service.dart';
import 'data/services/firebase_list_service.dart';
import 'data/services/firebase_push_service.dart';
import 'data/services/firebase_user_service.dart';
import 'data/services/http_send_worker.dart';
import 'data/services/identity.dart';
import 'data/services/in_memory_list_service.dart';
import 'data/services/local_list_store.dart';
import 'data/services/service_providers.dart';
import 'data/services/settings_service.dart';
import 'domain/models/app_settings.dart';
import 'domain/models/group.dart';
import 'l10n/l10n.dart';
import 'presentation/screens/app_gate.dart';
import 'presentation/view_models/groups/groups_view_model.dart';
import 'presentation/view_models/settings/settings_view_model.dart';
import 'presentation/view_models/settings/style_variant_view_model.dart';

// Web client id from google-services.json (client_type 3); not a secret.
const _serverClientId =
    '548461971411-fvv7f3ukkvduf26lahoouku616ibih8a.apps.googleusercontent.com';

// The Cloudflare Worker that finishes a send (backend/worker); deployed in plan step 61.6.
const _workerUrl = 'https://buyonce-worker.olive-lantern-4x9.workers.dev';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await GoogleSignIn.instance.initialize(serverClientId: _serverClientId);
  // The page runs under the system bars; the screens keep their own safe areas.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // The list made without an account stays on the device between starts.
  final localList = InMemoryListService();
  final localListStore = LocalListStore(SettingsService());
  await localListStore.attach(localList, personalGroupId(groupUserIds.first));
  runApp(
    ProviderScope(
      overrides: [
        inMemoryListServiceProvider.overrideWithValue(localList),
        realAccountServiceProvider.overrideWithValue(FirebaseAccountService()),
        realGroupServiceProvider.overrideWithValue(FirebaseGroupService()),
        realListServiceProvider.overrideWithValue(
          FirebaseListService(worker: HttpSendWorker(_workerUrl)),
        ),
        realUserServiceProvider.overrideWithValue(FirebaseUserService()),
        realPushServiceProvider.overrideWithValue(FirebasePushService()),
      ],
      child: const BuyOnceApp(),
    ),
  );
}

class BuyOnceApp extends ConsumerWidget {
  const BuyOnceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(pushRegistrationProvider);
    ref.watch(pushOpenProvider);
    ref.watch(localMergeProvider);
    final variant = ref.watch(styleVariantProvider);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BuyOnce',
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // null follows the phone; a phone with another language gets English (the
      // first supported locale).
      locale: switch (ref.watch(settingsProvider.select((s) => s.language))) {
        LanguageChoice.system => null,
        LanguageChoice.en => const Locale('en'),
        LanguageChoice.uk => const Locale('uk'),
      },
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
