import 'package:sound_mode/sound_mode.dart';
import 'package:sound_mode/utils/ringer_mode_statuses.dart';
import 'package:sound_mode/permission_handler.dart' as sm;

class RingerService {
  Future<RingerModeStatus> getStatus() => SoundMode.ringerModeStatus;

  Future<void> set(RingerModeStatus mode) => SoundMode.setSoundMode(mode);

  Future<bool> hasDndAccess() async =>
      (await sm.PermissionHandler.permissionsGranted) ?? false;

  Future<void> openDndSettings() =>
      sm.PermissionHandler.openDoNotDisturbSetting();
}
