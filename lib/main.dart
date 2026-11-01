import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'domain/models/app_settings.dart';
import 'presentation/view_models/settings/style_variant_view_model.dart';
import 'presentation/view_models/settings/settings_view_model.dart';
import 'presentation/screens/app_gate.dart';

void main() {
  runApp(const ProviderScope(child: BuyOnceApp()));
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
            value: Theme.of(context).brightness == Brightness.dark
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark,
            child: child!,
          ),
        );
      },
      home: const AppGate(),
    );
  }
}
