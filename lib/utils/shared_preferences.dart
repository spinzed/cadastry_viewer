import 'package:shared_preferences/shared_preferences.dart';

SharedPreferences? prefs;

Future<void> setupSharedPrefs() async {
  prefs = await SharedPreferences.getInstance();
}
