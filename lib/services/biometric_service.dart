
import 'package:local_auth/local_auth.dart';

/// Servicio de autenticación biométrica de FrostFit.
///
/// Android administra la validación de huella, rostro
/// y demás métodos biométricos compatibles.
///
/// La aplicación nunca almacena datos biométricos.
class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  /// Comprueba si el dispositivo puede utilizar biometría.
  Future<bool> get deviceSupportsBiometrics async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;

      return supported && canCheck;
    } catch (e) {
      return false;
    }
  }

  /// Consulta los tipos biométricos registrados.
  Future<List<BiometricType>> availableBiometrics() async {
    try {
      final supported = await deviceSupportsBiometrics;

      if (!supported) {
        return <BiometricType>[];
      }

      // No filtramos solamente huella y rostro.
      // Android puede reportar strong, weak o iris.
      return await _auth.getAvailableBiometrics();

    } catch (e) {
      return <BiometricType>[];
    }
  }

  /// Muestra los métodos disponibles.
  Future<String> availableMethodsLabel() async {
    try {
      final supported = await deviceSupportsBiometrics;

      if (!supported) {
        return 'Tu dispositivo no tiene biometría compatible disponible.';
      }

      final methods = await availableBiometrics();

      final hasFingerprint =
      methods.contains(BiometricType.fingerprint);

      final hasFace =
      methods.contains(BiometricType.face);

      final hasIris =
      methods.contains(BiometricType.iris);

      if (hasFingerprint && hasFace) {
        return 'Huella y reconocimiento facial disponibles.';
      }

      if (hasFingerprint) {
        return 'Huella dactilar disponible.';
      }

      if (hasFace) {
        return 'Reconocimiento facial disponible.';
      }

      if (hasIris) {
        return 'Reconocimiento de iris disponible.';
      }

      if (methods.contains(BiometricType.strong) ||
          methods.contains(BiometricType.weak)) {
        return 'Android detectó biometría compatible.';
      }

      return 'Android comprobará los métodos biométricos disponibles.';
    } catch (e) {
      return 'No fue posible consultar los métodos biométricos.';
    }
  }

  /// Solicita la autenticación biométrica nativa.
  ///
  /// Android decide qué sensor utilizar según el dispositivo.
  Future<bool> authenticateBiometric() async {
    try {
      final supported = await deviceSupportsBiometrics;

      if (!supported) {
        return false;
      }

      return await _auth.authenticate(
        localizedReason:
        'Verifica tu identidad con la huella o el rostro '
            'configurado en tu dispositivo para entrar a FrostFit.',

        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

    } catch (e) {
      return false;
    }
  }

  /// Compatibilidad con el código anterior.
  Future<bool> authenticateFingerprint() {
    return authenticateBiometric();
  }
}
