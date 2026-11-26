import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FrostProfile extends ChangeNotifier {
  static const avatars = ['🎅', '🤶', '⛄', '🦌', '🧝', '🎄', '🐧', '❄️'];

  String _user = '';
  String name = 'Atleta FrostFit';
  int age = 25;
  double weightKg = 70;
  double heightCm = 170;
  bool isMale = true;
  int avatar = 0;
  int stepGoal = 8000;

  String get avatarEmoji => avatars[avatar % avatars.length];

  // ---- Cálculos ----
  double get strideM => heightCm * (isMale ? 0.415 : 0.413) / 100;
  double distanceKm(int steps) => steps * strideM / 1000;
  double calories(int steps) => weightKg * distanceKm(steps) * 0.57;
  double get calorieGoal => calories(stepGoal);
  int activeMinutes(int steps) => (steps / 100).round();
  double get bmi => weightKg / ((heightCm / 100) * (heightCm / 100));
  String get bmiLabel => bmi < 18.5
      ? 'Bajo peso'
      : bmi < 25
      ? 'Saludable'
      : bmi < 30
      ? 'Sobrepeso'
      : 'Obesidad';
  double get bmr =>
      10 * weightKg + 6.25 * heightCm - 5 * age + (isMale ? 5 : -161);
  int get waterMl => (weightKg * 35).round();

  // ---- Guardado por usuario ----
  String _k(String key) => '${_user}_$key';

  Future<void> load(String user) async {
    _user = user;
    final p = await SharedPreferences.getInstance();
    name = p.getString(_k('name')) ?? user;
    age = p.getInt(_k('age')) ?? 25;
    weightKg = p.getDouble(_k('weight')) ?? 70;
    heightCm = p.getDouble(_k('height')) ?? 170;
    isMale = p.getBool(_k('male')) ?? true;
    avatar = p.getInt(_k('avatar')) ?? 0;
    stepGoal = p.getInt(_k('goal')) ?? 8000;
    notifyListeners();
  }

  Future<void> save() async {
    if (_user.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    await p.setString(_k('name'), name);
    await p.setInt(_k('age'), age);
    await p.setDouble(_k('weight'), weightKg);
    await p.setDouble(_k('height'), heightCm);
    await p.setBool(_k('male'), isMale);
    await p.setInt(_k('avatar'), avatar);
    await p.setInt(_k('goal'), stepGoal);
    notifyListeners();
  }
}

final frostProfile = FrostProfile();