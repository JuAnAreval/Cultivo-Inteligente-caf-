import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class DeviceLocationService {
  static Future<LatLng> getCurrentLatLng() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Activa la ubicación del dispositivo para continuar.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception('No se concedió permiso de ubicación.');
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'El permiso de ubicación está bloqueado. Debes habilitarlo desde ajustes.',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    return LatLng(position.latitude, position.longitude);
  }
}
