
import 'package:flutter/material.dart';
import '../services/biometric_service.dart';
import '../theme/app_theme.dart';
import 'app_shell.dart';

class LoginGate extends StatefulWidget {
  const LoginGate({super.key});

  @override
  State<LoginGate> createState() => _LoginGateState();
}

class _LoginGateState extends State<LoginGate> {
  bool _busy = false;
  bool _checking = true;
  bool _biometricAvailable = false;

  String _message =
      'Comprueba tu identidad para acceder a FrostFit.';

  String _methods = 'Comprobando seguridad del dispositivo...';

  final BiometricService _biometricService = BiometricService();

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      final available =
      await _biometricService.deviceSupportsBiometrics;

      final methods =
      await _biometricService.availableMethodsLabel();

      if (!mounted) return;

      setState(() {
        _biometricAvailable = available;
        _methods = methods;
        _checking = false;

        _message = available
            ? 'Tu dispositivo puede utilizar autenticación biométrica.'
            : 'No se detectó biometría compatible. Revisa los ajustes de seguridad de Android.';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _checking = false;
        _biometricAvailable = false;
        _message = 'No fue posible comprobar la biometría.';
        _methods = 'Comprueba la configuración de tu teléfono.';
      });
    }
  }

  Future<void> _authenticate() async {
    if (_busy || !_biometricAvailable) return;

    setState(() {
      _busy = true;
      _message = 'Esperando validación biométrica...';
    });

    try {
      final result =
      await _biometricService.authenticateBiometric();

      if (!mounted) return;

      setState(() {
        _busy = false;

        _message = result
            ? 'Identidad verificada correctamente.'
            : 'No se pudo validar tu identidad. Inténtalo nuevamente.';
      });

      if (result) {
        await Future.delayed(
          const Duration(milliseconds: 400),
        );

        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => const AppShell(),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _busy = false;
        _message =
        'Ocurrió un problema al validar tu identidad.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/frostfit_logo.png',
                  width: 230,
                  height: 230,
                  fit: BoxFit.contain,
                ),

                const SizedBox(height: 30),

                const Text(
                  'Tu entrenamiento, protegido',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 15),

                Text(
                  _message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 15,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  _methods,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.gold,
                    fontSize: 13,
                  ),
                ),

                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (_busy ||
                        _checking ||
                        !_biometricAvailable)
                        ? null
                        : _authenticate,

                    icon: _busy || _checking
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                        : const Icon(
                      Icons.fingerprint_rounded,
                    ),

                    label: Text(
                      _checking
                          ? 'COMPROBANDO...'
                          : _busy
                          ? 'VALIDANDO...'
                          : 'ENTRAR CON BIOMETRÍA',
                    ),

                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.mint,
                      foregroundColor: AppTheme.forest,
                      disabledBackgroundColor:
                      AppTheme.muted.withOpacity(0.3),
                      padding: const EdgeInsets.symmetric(
                        vertical: 18,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                if (!_checking && !_biometricAvailable)
                  OutlinedButton.icon(
                    onPressed: _checkBiometrics,
                    icon: const Icon(Icons.refresh),
                    label: const Text('VOLVER A COMPROBAR'),
                  ),

                const SizedBox(height: 22),

                const Text(
                  '🎄 Muévete con seguridad esta Navidad',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.gold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
