import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';

class PermissionService {
  static Future<bool> requestActivity() async {
    final status = await Permission.activityRecognition.request();
    return status.isGranted;
  }

  /// Solicita primero ubicación en uso y después permiso permanente.
  /// Android puede exigir que el usuario habilite "Permitir todo el tiempo" en Ajustes.
  static Future<bool> requestBackgroundLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var location = await Geolocator.checkPermission();
    if (location == LocationPermission.denied) {
      location = await Geolocator.requestPermission();
    }
    if (location == LocationPermission.denied || location == LocationPermission.deniedForever) {
      return false;
    }
    await Permission.notification.request();
    if (location == LocationPermission.whileInUse) {
      final always = await Permission.locationAlways.request();
      if (!always.isGranted) return false;
    }
    final current = await Geolocator.checkPermission();
    return current == LocationPermission.always || current == LocationPermission.whileInUse;
  }
}
