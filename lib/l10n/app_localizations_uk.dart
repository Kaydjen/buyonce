// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class AppLocalizationsUk extends AppLocalizations {
  AppLocalizationsUk([String locale = 'uk']) : super(locale);

  @override
  String get cancel => 'Скасувати';

  @override
  String get retry => 'Повторити';

  @override
  String get tabPlan => 'План';

  @override
  String get tabShop => 'Магазин';

  @override
  String get delete => 'Видалити';

  @override
  String get undo => 'Відмінити';

  @override
  String get add => 'Додати';

  @override
  String get nameHint => 'Ім’я';

  @override
  String get search => 'Пошук';

  @override
  String get save => 'Зберегти';

  @override
  String get continueLabel => 'Продовжити';

  @override
  String get create => 'Створити';

  @override
  String get join => 'Приєднатися';

  @override
  String get rename => 'Перейменувати';

  @override
  String get remove => 'Прибрати';

  @override
  String get system => 'Системна';

  @override
  String get offline => 'Офлайн';

  @override
  String get failedToLoad => 'Не вдалося завантажити';

  @override
  String get addProductsTitle => 'Додати продукти';

  @override
  String addCount(int count) {
    return 'Додати $count';
  }

  @override
  String removeProductTooltip(String name) {
    return 'Прибрати $name';
  }

  @override
  String get members => 'Учасники';

  @override
  String get owner => 'Власник';

  @override
  String get you => 'Ви';

  @override
  String get inviteCode => 'Код запрошення';

  @override
  String get copyCode => 'Скопіювати код';

  @override
  String get muteNotifications => 'Вимкнути сповіщення';

  @override
  String get leaveGroup => 'Вийти з групи';

  @override
  String get deleteGroup => 'Видалити групу';

  @override
  String get codeCopied => 'Код скопійовано';

  @override
  String removeMemberTitle(String name) {
    return 'Прибрати учасника $name?';
  }

  @override
  String removeMemberBody(String name, String group) {
    return '$name більше не бачитиме групу «$group».';
  }

  @override
  String removeMemberConfirm(String name) {
    return 'Прибрати $name';
  }

  @override
  String keepMember(String name) {
    return 'Залишити $name';
  }

  @override
  String leaveGroupTitle(String group) {
    return 'Вийти з групи «$group»?';
  }

  @override
  String get leaveGroupBody => 'Ви більше не бачитимете її списки.';

  @override
  String get stay => 'Залишитися';

  @override
  String deleteGroupTitle(String group) {
    return 'Видалити групу «$group»?';
  }

  @override
  String get deleteGroupBody => 'Її списки та плани буде видалено для всіх.';

  @override
  String get keepGroup => 'Залишити групу';

  @override
  String get history => 'Історія';

  @override
  String get noPurchasesYet => 'Покупок ще немає';

  @override
  String get today => 'Сьогодні';

  @override
  String get yesterday => 'Вчора';

  @override
  String addedCount(int n) {
    return 'Додано: $n';
  }

  @override
  String markedCount(int count) {
    return 'Відмічено: $count';
  }

  @override
  String sentCount(int n) {
    return 'Повідомлено: $n';
  }

  @override
  String doneCount(int n) {
    return 'Куплено: $n';
  }

  @override
  String notifiedCount(int n) {
    return 'Попросили: $n';
  }

  @override
  String get couldntSave => 'Не вдалося зберегти, спробуйте ще раз';

  @override
  String get send => 'Повідомити про покупки';

  @override
  String get done => 'Покупки зроблено';

  @override
  String get notify => 'Попросити купити';

  @override
  String get toBuy => 'Треба купити';

  @override
  String get toBuyWord => 'до купівлі';

  @override
  String get frequent => 'Часті';

  @override
  String get select => 'Що купити';

  @override
  String addQuery(String query) {
    return 'Додати «$query»';
  }

  @override
  String get find => 'Знайти';

  @override
  String get closeSearch => 'Закрити пошук';

  @override
  String shoppingTaken(String name, int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n товару',
      many: '$n товарів',
      few: '$n товари',
      one: '$n товар',
    );
    return '$name зараз у магазині. Відмічено: $_temp0';
  }

  @override
  String get menu => 'Меню';

  @override
  String get menuUpdateAvailable => 'Меню, є оновлення';

  @override
  String get sort => 'Сортувати';

  @override
  String get templates => 'Збережені списки';

  @override
  String get settings => 'Налаштування';

  @override
  String get newLabel => 'Нові товари';

  @override
  String newBy(String authors) {
    return 'Нове від: $authors';
  }

  @override
  String get markAll => 'Відмітити всі';

  @override
  String alreadyBoughtBy(String name) {
    return 'Це вже куплено: $name';
  }

  @override
  String get youAlreadyBought => 'Ви вже купили це';

  @override
  String get signInWithGoogle => 'Увійти через Google';

  @override
  String get continueWithoutAccount => 'Продовжити без входу';

  @override
  String enterNameLength(int max) {
    return 'Введіть від 1 до $max символів';
  }

  @override
  String get sending => 'Повідомлення';

  @override
  String get autoSend => 'Повідомляти автоматично';

  @override
  String get sendAfter => 'Повідомити через';

  @override
  String get theme => 'Тема';

  @override
  String get light => 'Світла';

  @override
  String get dark => 'Темна';

  @override
  String get textSize => 'Розмір тексту';

  @override
  String get language => 'Мова';

  @override
  String get account => 'Обліковий запис';

  @override
  String get about => 'Про застосунок';

  @override
  String secondsShort(int n) {
    return '$n с';
  }

  @override
  String minutesShort(int n) {
    return '$n хв';
  }

  @override
  String get googleAccount => 'Обліковий запис Google';

  @override
  String get signOut => 'Вийти';

  @override
  String get deleteAccount => 'Видалити обліковий запис';

  @override
  String get failedSignOut => 'Не вдалося вийти';

  @override
  String get deleteAccountTitle => 'Видалити обліковий запис?';

  @override
  String get deleteAccountBody =>
      'Ви вийдете з усіх груп, а ваші дані буде видалено. Це неможливо скасувати.';

  @override
  String get keepAccount => 'Залишити обліковий запис';

  @override
  String get couldntConfirm => 'Не вдалося підтвердити. Спробуйте ще раз.';

  @override
  String get failedDeleteAccount => 'Не вдалося видалити обліковий запис';

  @override
  String autoInSeconds(int n) {
    return 'Надішлеться через $n с';
  }

  @override
  String autoInMinutes(int n) {
    return 'Надішлеться через $n хв';
  }

  @override
  String autoAt(String time) {
    return 'Надішлеться о $time';
  }

  @override
  String get enterName => 'Введіть назву';

  @override
  String get noGroupWithCode => 'Групи з таким кодом немає';

  @override
  String get groupFull => 'Ця група заповнена';

  @override
  String get noConnection => 'Немає з’єднання';

  @override
  String get somethingWrong => 'Щось пішло не так';

  @override
  String get newGroup => 'Нова група';

  @override
  String get groupNameHint => 'Назва групи';

  @override
  String get joinGroup => 'Приєднатися до групи';

  @override
  String get codeHint => 'Код';

  @override
  String get renameGroup => 'Перейменувати групу';

  @override
  String get groupSettings => 'Налаштування групи';

  @override
  String noticeBought(String name, String items) {
    return '$name: куплено $items';
  }

  @override
  String noticeNeeded(String name, String items) {
    return '$name: потрібно $items';
  }

  @override
  String get recent => 'Останні';

  @override
  String get deleted => 'Видалені';

  @override
  String get pin => 'Зробити шаблоном';

  @override
  String get unpin => 'Прибрати з шаблонів';

  @override
  String get couldntSignIn => 'Не вдалося увійти';

  @override
  String get signInToUseGroups => 'Увійдіть, щоб користуватися групами';

  @override
  String get notNow => 'Не зараз';

  @override
  String get signIn => 'Увійти';

  @override
  String get sortAlphabetical => 'За алфавітом';

  @override
  String get sortFrequent => 'Найчастіші';

  @override
  String get sortRecent => 'Нещодавно куплені';

  @override
  String get licenses => 'Ліцензії';

  @override
  String get version => 'Версія';

  @override
  String updateTo(String version) {
    return 'Оновити до $version';
  }

  @override
  String get gemini => 'Gemini';

  @override
  String productDeleted(String name) {
    return 'Видалено: $name';
  }

  @override
  String get nameTaken => 'Вже є в списку';

  @override
  String get moveProduct => 'Перемістити';

  @override
  String get archive => 'Архів';

  @override
  String get restore => 'Відновити';

  @override
  String get photoTooltip => 'Фото';

  @override
  String modelLimitReached(String model) {
    return '$model: ліміт вичерпано';
  }

  @override
  String get addModels => 'Додати моделі';

  @override
  String get allModelsLimited => 'Ліміти всіх моделей вичерпано';

  @override
  String get couldntNameItem => 'Не вдалося назвати предмет';

  @override
  String get scanReceiptTooltip => 'Сканувати чек';

  @override
  String receiptPhotosTitle(int count) {
    return 'Фото: $count';
  }

  @override
  String get addPhoto => 'Додати фото';

  @override
  String get readReceipt => 'Прочитати';

  @override
  String get cameraDenied => 'Немає доступу до камери';

  @override
  String get cameraUnavailable => 'Камера недоступна';

  @override
  String get cameraLamp => 'Ліхтарик';

  @override
  String get cameraShoot => 'Зробити фото';

  @override
  String get cameraGallery => 'Галерея';

  @override
  String get closeCamera => 'Закрити';

  @override
  String get couldntReadReceipt => 'Не вдалося прочитати чек';

  @override
  String get receiptTitle => 'Чек';

  @override
  String receiptBoughtOf(int bought, int total) {
    return 'Куплено $bought з $total';
  }

  @override
  String get receiptCheckTitle => 'Перевірте назву';

  @override
  String get receiptInTitle => 'У чеку';

  @override
  String get receiptMissingTitle => 'Немає в чеку';

  @override
  String receiptMoreLines(int count) {
    return 'Ще рядків у чеку: $count';
  }

  @override
  String get receiptNoneOfThese => 'Жоден з цих';

  @override
  String get receiptViewTooltip => 'Фото чека';

  @override
  String markCount(int count) {
    return 'Відмітити $count';
  }

  @override
  String get models => 'Моделі';

  @override
  String get otherModel => 'Інша';

  @override
  String get modelId => 'ID моделі';

  @override
  String get invalidModelId => 'Це не ID моделі';

  @override
  String get modelAlreadyAdded => 'Вже є в списку';

  @override
  String get addApiKeyFirst => 'Спершу додайте ключ API';

  @override
  String get apiKeyRejected => 'Google не прийняв ключ API';

  @override
  String get reset => 'Скинути';

  @override
  String get apiKey => 'Ключ API';

  @override
  String get invalidApiKey => 'Це не схоже на ключ API';

  @override
  String get download => 'Завантажити';

  @override
  String get install => 'Встановити';

  @override
  String get amount => 'Кількість';

  @override
  String get amountMore => 'Більше';

  @override
  String get amountLess => 'Менше';

  @override
  String amountCount(int count) {
    return 'x$count';
  }

  @override
  String get unitKg => 'кг';

  @override
  String get unitG => 'г';

  @override
  String get unitL => 'л';

  @override
  String get unitMl => 'мл';

  @override
  String get unitWeight => 'кг/г';

  @override
  String get unitVolume => 'л/мл';
}
