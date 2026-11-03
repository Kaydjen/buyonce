import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../view_models/account/account_view_model.dart';
import '../view_models/groups/groups_view_model.dart';
import '../view_models/update/update_view_model.dart';
import '../widgets/load_failed.dart';
import 'list_screen.dart';
import 'login_screen.dart';
import 'name_screen.dart';

/// Login screen until the user signs in or continues without an account, the name screen
/// once after the first sign-in, then the lists of the shown group; every user has at
/// least the personal one.
class AppGate extends ConsumerWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The update check starts when the app opens.
    ref.read(updateViewModelProvider);
    final account = ref.watch(accountViewModelProvider);
    if (account.hasError) {
      return Scaffold(body: LoadFailed(onRetry: () => ref.invalidate(accountViewModelProvider)));
    }
    if (!account.hasValue) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (account.requireValue == null) {
      final local = ref.watch(localModeProvider);
      // The stored choice is still being read: no login screen flash.
      if (local == null) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (!local) return const LoginScreen();
    }
    if (ref.watch(namePendingProvider)) return const NameScreen();
    final groups = ref.watch(groupsViewModelProvider);
    if (groups.hasError) {
      return Scaffold(body: LoadFailed(onRetry: () => ref.invalidate(groupsViewModelProvider)));
    }
    if (!groups.hasValue) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return ref.watch(activeGroupIdProvider) == null
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : const ListScreen();
  }
}
