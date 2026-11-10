// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get cancel => 'Cancel';

  @override
  String get retry => 'Retry';

  @override
  String get tabPlan => 'Plan';

  @override
  String get tabShop => 'Shop';

  @override
  String get delete => 'Delete';

  @override
  String get undo => 'Undo';

  @override
  String get add => 'Add';

  @override
  String get nameHint => 'Name';

  @override
  String get search => 'Search';

  @override
  String get save => 'Save';

  @override
  String get continueLabel => 'Continue';

  @override
  String get create => 'Create';

  @override
  String get join => 'Join';

  @override
  String get rename => 'Rename';

  @override
  String get remove => 'Remove';

  @override
  String get system => 'System';

  @override
  String get offline => 'Offline';

  @override
  String get failedToLoad => 'Failed to load';

  @override
  String get addProductsTitle => 'Add products';

  @override
  String addCount(int count) {
    return 'Add $count';
  }

  @override
  String removeProductTooltip(String name) {
    return 'Remove $name';
  }

  @override
  String get members => 'Members';

  @override
  String get owner => 'Owner';

  @override
  String get you => 'You';

  @override
  String get inviteCode => 'Invite code';

  @override
  String get copyCode => 'Copy code';

  @override
  String get muteNotifications => 'Mute notifications';

  @override
  String get leaveGroup => 'Leave group';

  @override
  String get deleteGroup => 'Delete group';

  @override
  String get codeCopied => 'Code copied';

  @override
  String removeMemberTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String removeMemberBody(String name, String group) {
    return '$name stops seeing $group.';
  }

  @override
  String removeMemberConfirm(String name) {
    return 'Remove $name';
  }

  @override
  String keepMember(String name) {
    return 'Keep $name';
  }

  @override
  String leaveGroupTitle(String group) {
    return 'Leave $group?';
  }

  @override
  String get leaveGroupBody => 'You stop seeing its lists.';

  @override
  String get stay => 'Stay';

  @override
  String deleteGroupTitle(String group) {
    return 'Delete $group?';
  }

  @override
  String get deleteGroupBody => 'Its lists and plans are deleted for everyone.';

  @override
  String get keepGroup => 'Keep group';

  @override
  String get history => 'History';

  @override
  String get noPurchasesYet => 'No purchases yet';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String addedCount(int n) {
    return 'Added: $n';
  }

  @override
  String markedCount(int n) {
    return 'Marked: $n';
  }

  @override
  String sentCount(int n) {
    return 'Sent $n';
  }

  @override
  String doneCount(int n) {
    return 'Done $n';
  }

  @override
  String notifiedCount(int n) {
    return 'Notified $n';
  }

  @override
  String get couldntSave => 'Couldn\'t save, try again';

  @override
  String get send => 'Send';

  @override
  String get done => 'Done';

  @override
  String get notify => 'Notify';

  @override
  String get toBuy => 'To buy';

  @override
  String get toBuyWord => 'to buy';

  @override
  String get frequent => 'Frequent';

  @override
  String get select => 'Select';

  @override
  String addQuery(String query) {
    return 'Add \"$query\"';
  }

  @override
  String get find => 'Find';

  @override
  String get closeSearch => 'Close search';

  @override
  String shoppingTaken(String name, int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n items',
      one: '$n item',
    );
    return '$name is at the store, $_temp0 marked';
  }

  @override
  String get menu => 'Menu';

  @override
  String get menuUpdateAvailable => 'Menu, update available';

  @override
  String get sort => 'Sort';

  @override
  String get templates => 'Templates';

  @override
  String get settings => 'Settings';

  @override
  String get newLabel => 'New';

  @override
  String newBy(String authors) {
    return 'New · $authors';
  }

  @override
  String get markAll => 'Mark all';

  @override
  String alreadyBoughtBy(String name) {
    return '$name already bought this';
  }

  @override
  String get youAlreadyBought => 'You already bought this';

  @override
  String get signInWithGoogle => 'Sign in with Google';

  @override
  String get continueWithoutAccount => 'Continue without account';

  @override
  String enterNameLength(int max) {
    return 'Enter 1-$max characters';
  }

  @override
  String get sending => 'Sending';

  @override
  String get autoSend => 'Auto-send';

  @override
  String get sendAfter => 'Send after';

  @override
  String get theme => 'Theme';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get textSize => 'Text size';

  @override
  String get language => 'Language';

  @override
  String get account => 'Account';

  @override
  String get about => 'About';

  @override
  String secondsShort(int n) {
    return '$n s';
  }

  @override
  String minutesShort(int n) {
    return '$n min';
  }

  @override
  String get googleAccount => 'Google account';

  @override
  String get signOut => 'Sign out';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get failedSignOut => 'Failed to sign out';

  @override
  String get deleteAccountTitle => 'Delete account?';

  @override
  String get deleteAccountBody =>
      'You leave all groups and your data is deleted. This cannot be undone.';

  @override
  String get keepAccount => 'Keep account';

  @override
  String get couldntConfirm => 'Couldn\'t confirm. Try again.';

  @override
  String get failedDeleteAccount => 'Failed to delete the account';

  @override
  String autoInSeconds(int n) {
    return 'Auto · in $n s';
  }

  @override
  String autoInMinutes(int n) {
    return 'Auto · in $n min';
  }

  @override
  String autoAt(String time) {
    return 'Auto · $time';
  }

  @override
  String get enterName => 'Enter a name';

  @override
  String get noGroupWithCode => 'No group with this code';

  @override
  String get groupFull => 'This group is full';

  @override
  String get noConnection => 'No connection';

  @override
  String get somethingWrong => 'Something went wrong';

  @override
  String get newGroup => 'New group';

  @override
  String get groupNameHint => 'Group name';

  @override
  String get joinGroup => 'Join group';

  @override
  String get codeHint => 'Code';

  @override
  String get renameGroup => 'Rename group';

  @override
  String get groupSettings => 'Group settings';

  @override
  String noticeBought(String name, String items) {
    return '$name bought: $items';
  }

  @override
  String noticeNeeded(String name, String items) {
    return '$name needs: $items';
  }

  @override
  String get recent => 'Recent';

  @override
  String get deleted => 'Deleted';

  @override
  String get pin => 'Pin';

  @override
  String get unpin => 'Unpin';

  @override
  String get couldntSignIn => 'Couldn\'t sign in';

  @override
  String get signInToUseGroups => 'Sign in to use groups';

  @override
  String get notNow => 'Not now';

  @override
  String get signIn => 'Sign in';

  @override
  String get sortAlphabetical => 'Alphabetical';

  @override
  String get sortFrequent => 'Most frequent';

  @override
  String get sortRecent => 'Recently bought';

  @override
  String get licenses => 'Licenses';

  @override
  String get version => 'Version';

  @override
  String updateTo(String version) {
    return 'Update to $version';
  }

  @override
  String get gemini => 'Gemini';

  @override
  String get apiKey => 'API key';

  @override
  String get invalidApiKey => 'That is not an API key';

  @override
  String get download => 'Download';

  @override
  String get install => 'Install';
}
