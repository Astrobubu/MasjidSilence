import 'package:shared_preferences/shared_preferences.dart';
import '../app/constants.dart';

class PinService {
  Future<void> save(double lat, double lon) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(kPrefsPinLat, lat);
    await prefs.setDouble(kPrefsPinLon, lon);
  }

  Future<(double?, double?)> load() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getDouble(kPrefsPinLat), prefs.getDouble(kPrefsPinLon));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kPrefsPinLat);
    await prefs.remove(kPrefsPinLon);
  }
}
