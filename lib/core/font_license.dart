import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Adds the Montserrat font license to the licenses page: the font ships inside
/// the app, and its license asks for the notice to travel with it.
void registerFontLicense() {
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/fonts/OFL-Montserrat.txt');
    yield LicenseEntryWithLineBreaks(['Montserrat'], text);
  });
}
