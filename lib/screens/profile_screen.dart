import 'package:flutter/material.dart';
import '../models/frost_profile.dart';
import '../services/biometric_service.dart';
import '../theme/app_theme.dart';
import 'frost_profile_screen.dart';
import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _unlocked = false, _busy = false;

  Future<void> _unlock() async {
    setState(() => _busy = true);
    final ok = await BiometricService().authenticateBiometric();
    if (!mounted) return;
    setState(() { _busy = false; _unlocked = ok; });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Identidad verificada. Acceso concedido.' : 'No se pudo validar la biometría.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    // Desbloqueado: perfil editable (trae su propio título y nieve).
    if (_unlocked) {
      return ListenableBuilder(
        listenable: auth,
        builder: (_, __) => Scaffold(
          body: FrostProfileScreen(key: ValueKey(auth.user), profile: frostProfile),
        ),
      );
    }

    // Bloqueado: tu pantalla original.
    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil', style: TextStyle(fontWeight: FontWeight.w800))),
      body: Center(child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 110, height: 110, decoration: BoxDecoration(
            color: AppTheme.panel, borderRadius: BorderRadius.circular(35),
            border: Border.all(color: AppTheme.mint.withOpacity(.4)),
          ), child: const Icon(Icons.person_rounded, color: AppTheme.mint, size: 58)),
          const SizedBox(height: 20),
          const Text('Perfil FrostFit', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('Verifica tu identidad para consultar tu perfil.',
              textAlign: TextAlign.center, style: TextStyle(color: AppTheme.muted)),
          const SizedBox(height: 22),
          ElevatedButton.icon(
            onPressed: _busy ? null : _unlock,
            icon: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.face_retouching_natural_rounded),
            label: Text(_busy ? 'VALIDANDO...' : 'DESBLOQUEAR CON HUELLA O ROSTRO'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.mint,
              foregroundColor: AppTheme.forest,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
          ),
        ]),
      )),
    );
  }
}