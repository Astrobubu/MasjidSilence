import 'package:geofence_foreground_service/geofence_foreground_service.dart';
import 'package:geofence_foreground_service/constants/geofence_event_type.dart';
import 'package:sound_mode/sound_mode.dart';
import 'package:sound_mode/utils/ringer_mode_statuses.dart';

@pragma('vm:entry-point')
void geofenceCallbackDispatcher() async {
  GeofenceForegroundService().handleTrigger(
    backgroundTriggerHandler: (zoneId, triggerType) async {
      try {
        if (triggerType == GeofenceEventType.enter) {
          // Respect user preference: vibrate or silent
          // We can't read from store here easily; default to silent. Foreground will correct state soon after.
          try {
            await SoundMode.setSoundMode(RingerModeStatus.silent);
          } catch (_) {}
        } else if (triggerType == GeofenceEventType.exit) {
          try {
            await SoundMode.setSoundMode(RingerModeStatus.normal);
          } catch (_) {}
        }
      } catch (_) {}
      return Future.value(true);
    },
  );
}
