import 'package:flutter/material.dart';
import 'screens/login_gate.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await auth.init(); // carga el último perfil usado
  runApp(const FitnessChristmasApp());
}

class FitnessChristmasApp extends StatelessWidget {
  const FitnessChristmasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FrostFit',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const LoginGate(),
    );
  }
}