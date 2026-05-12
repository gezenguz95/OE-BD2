import 'package:flutter/foundation.dart';
import 'app_settings.dart';
import '../l10n/app_localizations.dart';

class LocaleNotifier extends ChangeNotifier {
  String _code;

  LocaleNotifier(String savedCode) : _code = _valid(savedCode);

  String get languageCode => _code;

  AppLocalizations get strings => AppLocalizations.of(_code);

  Future<void> setLanguage(String code) async {
    final c = _valid(code);
    if (_code == c) return;
    _code = c;
    notifyListeners();
    try {
      await AppSettings().setLanguageCode(c);
    } catch (e) {
      debugPrint('LocaleNotifier persist failed: $e');
    }
  }

  static String _valid(String code) =>
      code == 'en' ? 'en' : 'hu';
}
