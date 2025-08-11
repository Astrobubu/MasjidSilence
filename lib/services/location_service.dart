import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  Future<bool> ensurePermission({bool background = false}) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return false;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      return false;
    }
    if (background) {
      final bg = await Permission.locationAlways.request();
      if (!bg.isGranted) return false;
    }
    return perm == LocationPermission.whileInUse ||
        perm == LocationPermission.always;
  }

  Future<Position> currentPosition() =>
      Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

  String pretty(Position p) =>
      '${p.latitude.toStringAsFixed(6)}, ${p.longitude.toStringAsFixed(6)} (±${p.accuracy.toStringAsFixed(0)} m)';

  double distanceMeters({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
  }) => Geolocator.distanceBetween(fromLat, fromLon, toLat, toLon);
}
