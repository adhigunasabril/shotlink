import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  final SharedPreferences _prefs;

  PreferencesService(this._prefs);

  static const String _keyCountryDialCode = 'selected_country_dial_code';
  static const String _keyCountryName = 'selected_country_name';

  String? getCountryDialCode() {
    return _prefs.getString(_keyCountryDialCode);
  }

  Future<void> setCountryDialCode(String dialCode) async {
    await _prefs.setString(_keyCountryDialCode, dialCode);
  }

  String? getCountryName() {
    return _prefs.getString(_keyCountryName);
  }

  Future<void> setCountryName(String name) async {
    await _prefs.setString(_keyCountryName, name);
  }
  
  bool isCountryConfigured() {
    return getCountryDialCode() != null;
  }
}
