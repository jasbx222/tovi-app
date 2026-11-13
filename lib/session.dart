import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'copy.dart';

class Session extends ChangeNotifier {
  Session(this.prefs) {
    token = prefs.getString('tovi-token') ?? '';
    arabic = prefs.getBool('tovi-ar') ?? true;
  }

  final SharedPreferences prefs;
  String token = '';
  bool arabic = true;

  static const base = String.fromEnvironment('API_URL', defaultValue: 'http://127.0.0.1:5088');
  static const buildEnvironment = String.fromEnvironment('TOVI_ENV', defaultValue: 'development');

  Copy get copy => Copy(arabic);
  ToviApi get api => ToviApi(base: base, token: token);
  bool get signedIn => token.isNotEmpty;

  Future<void> signIn(String value) async {
    token = value;
    await prefs.setString('tovi-token', value);
    notifyListeners();
  }

  Future<void> signOut() async {
    token = '';
    await prefs.remove('tovi-token');
    notifyListeners();
  }

  Future<void> toggleLanguage() async {
    arabic = !arabic;
    await prefs.setBool('tovi-ar', arabic);
    notifyListeners();
  }
}
