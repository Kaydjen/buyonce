import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// The English name of the app language, for names the model has to invent.
String receiptLanguage(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'uk'
    ? 'Ukrainian'
    : 'English';

/// A currency for a receipt that prints none: the phone's own region.
String receiptFallbackCurrency(BuildContext context) =>
    NumberFormat.simpleCurrency(
      locale: Localizations.localeOf(context).toLanguageTag(),
    ).currencyName ??
    'USD';
