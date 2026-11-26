import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/frost_profile.dart';

class AuthService extends ChangeNotifier {
  List<String> users = ['Principal'];
  String user = 'Principal';

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    users = p.getStringList('profiles') ?? ['Principal'];
    user = p.getString('active_profile') ?? users.first;
    if (!users.contains(user)) user = users.first;
    await frostProfile.load(user);
  }

  Future<void> _activate(String name) async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList('profiles', users);
    await p.setString('active_profile', name);
    user = name;
    await frostProfile.load(name);
    notifyListeners();
  }

  Future<void> switchTo(String name) => _activate(name);

  /// Devuelve null si salió bien, o el mensaje de error.
  Future<String?> create(String name) async {
    name = name.trim();
    if (name.isEmpty) return 'Escribe un nombre';
    if (users.any((u) => u.toLowerCase() == name.toLowerCase())) {
      return 'Ese perfil ya existe';
    }
    users = [...users, name];
    await _activate(name);
    return null;
  }
}

final auth = AuthService();