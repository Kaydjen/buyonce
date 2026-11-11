import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_uk.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('uk'),
  ];

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @tabPlan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get tabPlan;

  /// No description provided for @tabShop.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get tabShop;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @nameHint.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nameHint;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @join.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get join;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @failedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load'**
  String get failedToLoad;

  /// No description provided for @addProductsTitle.
  ///
  /// In en, this message translates to:
  /// **'Add products'**
  String get addProductsTitle;

  /// No description provided for @addCount.
  ///
  /// In en, this message translates to:
  /// **'Add {count}'**
  String addCount(int count);

  /// No description provided for @removeProductTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}'**
  String removeProductTooltip(String name);

  /// No description provided for @members.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get members;

  /// No description provided for @owner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get owner;

  /// No description provided for @you.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get you;

  /// No description provided for @inviteCode.
  ///
  /// In en, this message translates to:
  /// **'Invite code'**
  String get inviteCode;

  /// No description provided for @copyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get copyCode;

  /// No description provided for @muteNotifications.
  ///
  /// In en, this message translates to:
  /// **'Mute notifications'**
  String get muteNotifications;

  /// No description provided for @leaveGroup.
  ///
  /// In en, this message translates to:
  /// **'Leave group'**
  String get leaveGroup;

  /// No description provided for @deleteGroup.
  ///
  /// In en, this message translates to:
  /// **'Delete group'**
  String get deleteGroup;

  /// No description provided for @codeCopied.
  ///
  /// In en, this message translates to:
  /// **'Code copied'**
  String get codeCopied;

  /// No description provided for @removeMemberTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String removeMemberTitle(String name);

  /// No description provided for @removeMemberBody.
  ///
  /// In en, this message translates to:
  /// **'{name} stops seeing {group}.'**
  String removeMemberBody(String name, String group);

  /// No description provided for @removeMemberConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}'**
  String removeMemberConfirm(String name);

  /// No description provided for @keepMember.
  ///
  /// In en, this message translates to:
  /// **'Keep {name}'**
  String keepMember(String name);

  /// No description provided for @leaveGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave {group}?'**
  String leaveGroupTitle(String group);

  /// No description provided for @leaveGroupBody.
  ///
  /// In en, this message translates to:
  /// **'You stop seeing its lists.'**
  String get leaveGroupBody;

  /// No description provided for @stay.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get stay;

  /// No description provided for @deleteGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {group}?'**
  String deleteGroupTitle(String group);

  /// No description provided for @deleteGroupBody.
  ///
  /// In en, this message translates to:
  /// **'Its lists and plans are deleted for everyone.'**
  String get deleteGroupBody;

  /// No description provided for @keepGroup.
  ///
  /// In en, this message translates to:
  /// **'Keep group'**
  String get keepGroup;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @noPurchasesYet.
  ///
  /// In en, this message translates to:
  /// **'No purchases yet'**
  String get noPurchasesYet;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @addedCount.
  ///
  /// In en, this message translates to:
  /// **'Added: {n}'**
  String addedCount(int n);

  /// No description provided for @markedCount.
  ///
  /// In en, this message translates to:
  /// **'Marked: {count}'**
  String markedCount(int count);

  /// No description provided for @sentCount.
  ///
  /// In en, this message translates to:
  /// **'Sent {n}'**
  String sentCount(int n);

  /// No description provided for @doneCount.
  ///
  /// In en, this message translates to:
  /// **'Done {n}'**
  String doneCount(int n);

  /// No description provided for @notifiedCount.
  ///
  /// In en, this message translates to:
  /// **'Notified {n}'**
  String notifiedCount(int n);

  /// No description provided for @couldntSave.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save, try again'**
  String get couldntSave;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @notify.
  ///
  /// In en, this message translates to:
  /// **'Notify'**
  String get notify;

  /// No description provided for @toBuy.
  ///
  /// In en, this message translates to:
  /// **'To buy'**
  String get toBuy;

  /// No description provided for @toBuyWord.
  ///
  /// In en, this message translates to:
  /// **'to buy'**
  String get toBuyWord;

  /// No description provided for @frequent.
  ///
  /// In en, this message translates to:
  /// **'Frequent'**
  String get frequent;

  /// No description provided for @select.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get select;

  /// No description provided for @addQuery.
  ///
  /// In en, this message translates to:
  /// **'Add \"{query}\"'**
  String addQuery(String query);

  /// No description provided for @find.
  ///
  /// In en, this message translates to:
  /// **'Find'**
  String get find;

  /// No description provided for @closeSearch.
  ///
  /// In en, this message translates to:
  /// **'Close search'**
  String get closeSearch;

  /// No description provided for @shoppingTaken.
  ///
  /// In en, this message translates to:
  /// **'{name} is at the store, {n, plural, one{{n} item} other{{n} items}} marked'**
  String shoppingTaken(String name, int n);

  /// No description provided for @menu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menu;

  /// No description provided for @menuUpdateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Menu, update available'**
  String get menuUpdateAvailable;

  /// No description provided for @sort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sort;

  /// No description provided for @templates.
  ///
  /// In en, this message translates to:
  /// **'Templates'**
  String get templates;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @newLabel.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newLabel;

  /// No description provided for @newBy.
  ///
  /// In en, this message translates to:
  /// **'New · {authors}'**
  String newBy(String authors);

  /// No description provided for @markAll.
  ///
  /// In en, this message translates to:
  /// **'Mark all'**
  String get markAll;

  /// No description provided for @alreadyBoughtBy.
  ///
  /// In en, this message translates to:
  /// **'{name} already bought this'**
  String alreadyBoughtBy(String name);

  /// No description provided for @youAlreadyBought.
  ///
  /// In en, this message translates to:
  /// **'You already bought this'**
  String get youAlreadyBought;

  /// No description provided for @signInWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get signInWithGoogle;

  /// No description provided for @continueWithoutAccount.
  ///
  /// In en, this message translates to:
  /// **'Continue without account'**
  String get continueWithoutAccount;

  /// No description provided for @enterNameLength.
  ///
  /// In en, this message translates to:
  /// **'Enter 1-{max} characters'**
  String enterNameLength(int max);

  /// No description provided for @sending.
  ///
  /// In en, this message translates to:
  /// **'Sending'**
  String get sending;

  /// No description provided for @autoSend.
  ///
  /// In en, this message translates to:
  /// **'Auto-send'**
  String get autoSend;

  /// No description provided for @sendAfter.
  ///
  /// In en, this message translates to:
  /// **'Send after'**
  String get sendAfter;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @textSize.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get textSize;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @secondsShort.
  ///
  /// In en, this message translates to:
  /// **'{n} s'**
  String secondsShort(int n);

  /// No description provided for @minutesShort.
  ///
  /// In en, this message translates to:
  /// **'{n} min'**
  String minutesShort(int n);

  /// No description provided for @googleAccount.
  ///
  /// In en, this message translates to:
  /// **'Google account'**
  String get googleAccount;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// No description provided for @failedSignOut.
  ///
  /// In en, this message translates to:
  /// **'Failed to sign out'**
  String get failedSignOut;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete account?'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountBody.
  ///
  /// In en, this message translates to:
  /// **'You leave all groups and your data is deleted. This cannot be undone.'**
  String get deleteAccountBody;

  /// No description provided for @keepAccount.
  ///
  /// In en, this message translates to:
  /// **'Keep account'**
  String get keepAccount;

  /// No description provided for @couldntConfirm.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t confirm. Try again.'**
  String get couldntConfirm;

  /// No description provided for @failedDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete the account'**
  String get failedDeleteAccount;

  /// No description provided for @autoInSeconds.
  ///
  /// In en, this message translates to:
  /// **'Auto · in {n} s'**
  String autoInSeconds(int n);

  /// No description provided for @autoInMinutes.
  ///
  /// In en, this message translates to:
  /// **'Auto · in {n} min'**
  String autoInMinutes(int n);

  /// No description provided for @autoAt.
  ///
  /// In en, this message translates to:
  /// **'Auto · {time}'**
  String autoAt(String time);

  /// No description provided for @enterName.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get enterName;

  /// No description provided for @noGroupWithCode.
  ///
  /// In en, this message translates to:
  /// **'No group with this code'**
  String get noGroupWithCode;

  /// No description provided for @groupFull.
  ///
  /// In en, this message translates to:
  /// **'This group is full'**
  String get groupFull;

  /// No description provided for @noConnection.
  ///
  /// In en, this message translates to:
  /// **'No connection'**
  String get noConnection;

  /// No description provided for @somethingWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get somethingWrong;

  /// No description provided for @newGroup.
  ///
  /// In en, this message translates to:
  /// **'New group'**
  String get newGroup;

  /// No description provided for @groupNameHint.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get groupNameHint;

  /// No description provided for @joinGroup.
  ///
  /// In en, this message translates to:
  /// **'Join group'**
  String get joinGroup;

  /// No description provided for @codeHint.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get codeHint;

  /// No description provided for @renameGroup.
  ///
  /// In en, this message translates to:
  /// **'Rename group'**
  String get renameGroup;

  /// No description provided for @groupSettings.
  ///
  /// In en, this message translates to:
  /// **'Group settings'**
  String get groupSettings;

  /// No description provided for @noticeBought.
  ///
  /// In en, this message translates to:
  /// **'{name} bought: {items}'**
  String noticeBought(String name, String items);

  /// No description provided for @noticeNeeded.
  ///
  /// In en, this message translates to:
  /// **'{name} needs: {items}'**
  String noticeNeeded(String name, String items);

  /// No description provided for @recent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get recent;

  /// No description provided for @deleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get deleted;

  /// No description provided for @pin.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get pin;

  /// No description provided for @unpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get unpin;

  /// No description provided for @couldntSignIn.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t sign in'**
  String get couldntSignIn;

  /// No description provided for @signInToUseGroups.
  ///
  /// In en, this message translates to:
  /// **'Sign in to use groups'**
  String get signInToUseGroups;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @sortAlphabetical.
  ///
  /// In en, this message translates to:
  /// **'Alphabetical'**
  String get sortAlphabetical;

  /// No description provided for @sortFrequent.
  ///
  /// In en, this message translates to:
  /// **'Most frequent'**
  String get sortFrequent;

  /// No description provided for @sortRecent.
  ///
  /// In en, this message translates to:
  /// **'Recently bought'**
  String get sortRecent;

  /// No description provided for @licenses.
  ///
  /// In en, this message translates to:
  /// **'Licenses'**
  String get licenses;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @updateTo.
  ///
  /// In en, this message translates to:
  /// **'Update to {version}'**
  String updateTo(String version);

  /// No description provided for @gemini.
  ///
  /// In en, this message translates to:
  /// **'Gemini'**
  String get gemini;

  /// No description provided for @productDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted: {name}'**
  String productDeleted(String name);

  /// No description provided for @nameTaken.
  ///
  /// In en, this message translates to:
  /// **'Already in the list'**
  String get nameTaken;

  /// No description provided for @moveProduct.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get moveProduct;

  /// No description provided for @archive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archive;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @photoTooltip.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get photoTooltip;

  /// No description provided for @modelLimitReached.
  ///
  /// In en, this message translates to:
  /// **'{model}: limit reached'**
  String modelLimitReached(String model);

  /// No description provided for @addModels.
  ///
  /// In en, this message translates to:
  /// **'Add models'**
  String get addModels;

  /// No description provided for @allModelsLimited.
  ///
  /// In en, this message translates to:
  /// **'All models reached their limit'**
  String get allModelsLimited;

  /// No description provided for @couldntNameItem.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t name this item'**
  String get couldntNameItem;

  /// No description provided for @scanReceiptTooltip.
  ///
  /// In en, this message translates to:
  /// **'Scan receipt'**
  String get scanReceiptTooltip;

  /// No description provided for @receiptPhotosTitle.
  ///
  /// In en, this message translates to:
  /// **'Photos: {count}'**
  String receiptPhotosTitle(int count);

  /// No description provided for @addPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get addPhoto;

  /// No description provided for @readReceipt.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get readReceipt;

  /// No description provided for @couldntReadReceipt.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read this receipt'**
  String get couldntReadReceipt;

  /// No description provided for @receiptTitle.
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get receiptTitle;

  /// No description provided for @receiptFound.
  ///
  /// In en, this message translates to:
  /// **'Found'**
  String get receiptFound;

  /// No description provided for @receiptSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped: {count}'**
  String receiptSkipped(int count);

  /// No description provided for @selectAllNew.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selectAllNew;

  /// No description provided for @markCount.
  ///
  /// In en, this message translates to:
  /// **'Mark {count}'**
  String markCount(int count);

  /// No description provided for @pricesMayBeMisread.
  ///
  /// In en, this message translates to:
  /// **'Prices may be misread'**
  String get pricesMayBeMisread;

  /// No description provided for @newProduct.
  ///
  /// In en, this message translates to:
  /// **'New product'**
  String get newProduct;

  /// No description provided for @models.
  ///
  /// In en, this message translates to:
  /// **'Models'**
  String get models;

  /// No description provided for @otherModel.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get otherModel;

  /// No description provided for @modelId.
  ///
  /// In en, this message translates to:
  /// **'Model ID'**
  String get modelId;

  /// No description provided for @invalidModelId.
  ///
  /// In en, this message translates to:
  /// **'That is not a model ID'**
  String get invalidModelId;

  /// No description provided for @modelAlreadyAdded.
  ///
  /// In en, this message translates to:
  /// **'Already in the list'**
  String get modelAlreadyAdded;

  /// No description provided for @addApiKeyFirst.
  ///
  /// In en, this message translates to:
  /// **'Add an API key first'**
  String get addApiKeyFirst;

  /// No description provided for @apiKeyRejected.
  ///
  /// In en, this message translates to:
  /// **'Google did not accept the API key'**
  String get apiKeyRejected;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @apiKey.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get apiKey;

  /// No description provided for @invalidApiKey.
  ///
  /// In en, this message translates to:
  /// **'That is not an API key'**
  String get invalidApiKey;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @install.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get install;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @amountMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get amountMore;

  /// No description provided for @amountLess.
  ///
  /// In en, this message translates to:
  /// **'Less'**
  String get amountLess;

  /// No description provided for @amountCount.
  ///
  /// In en, this message translates to:
  /// **'x{count}'**
  String amountCount(int count);

  /// No description provided for @unitKg.
  ///
  /// In en, this message translates to:
  /// **'kg'**
  String get unitKg;

  /// No description provided for @unitG.
  ///
  /// In en, this message translates to:
  /// **'g'**
  String get unitG;

  /// No description provided for @unitL.
  ///
  /// In en, this message translates to:
  /// **'l'**
  String get unitL;

  /// No description provided for @unitMl.
  ///
  /// In en, this message translates to:
  /// **'ml'**
  String get unitMl;

  /// No description provided for @unitWeight.
  ///
  /// In en, this message translates to:
  /// **'kg/g'**
  String get unitWeight;

  /// No description provided for @unitVolume.
  ///
  /// In en, this message translates to:
  /// **'l/ml'**
  String get unitVolume;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'uk'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'uk':
      return AppLocalizationsUk();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
