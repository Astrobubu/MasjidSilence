import 'package:geofence_foreground_service/geofence_foreground_service.dart';
import 'package:geofence_foreground_service/constants/geofence_event_type.dart';
import 'package:geofence_foreground_service/models/zone.dart';
import 'package:latlng/latlng.dart';
import '../app/constants.dart';
import '../background/callback.dart';
import '../models/mosque_location.dart';

class GeoFenceService {
  Future<bool> startWithLocations(
    List<MosqueLocation> locs, {
    String? contentTitle,
    String? contentText,
  }) async {
    if (locs.isEmpty) return false;

    try {
      final started = await GeofenceForegroundService().startGeofencingService(
        contentTitle: contentTitle ?? 'MosqueSilence',
        contentText: contentText ?? 'Monitoring ${locs.length} location${locs.length == 1 ? '' : 's'}',
        notificationChannelId: kServiceChannelId,
        serviceId: kServiceNotificationId,
        callbackDispatcher: geofenceCallbackDispatcher,
      );
      
      if (!started) {
        print('Failed to start geofencing service');
        return false;
      }

      // Add zones with error handling
      for (final m in locs) {
        try {
          await GeofenceForegroundService().addGeofenceZone(
            zone: Zone(
              id: m.id,
              radius: m.radius,
              coordinates: [LatLng.degree(m.lat, m.lon)],
              triggers: const [GeofenceEventType.enter, GeofenceEventType.exit],
              initialTrigger: GeofenceEventType.enter,
              expirationDuration: const Duration(days: 365),
            ),
          );
        } catch (e) {
          print('Failed to add geofence zone for ${m.label}: $e');
        }
      }
      return true;
    } catch (e) {
      print('Error starting geofence service: $e');
      return false;
    }
  }

  Future<void> stop() => GeofenceForegroundService().stopGeofencingService();

  /// Easiest sync strategy: stop then start with the new set.
  Future<bool> restartWithLocations(
    List<MosqueLocation> locs, {
    String? contentTitle,
    String? contentText,
  }) async {
    await stop();
    return startWithLocations(
      locs,
      contentTitle: contentTitle,
      contentText: contentText,
    );
  }
}
