import 'package:flutter/services.dart';
import 'mosquesilence_dnd_platform_interface.dart';

class MosqueSilenceDnd {
  static const _ch = MethodChannel('mosquesilence/dnd');

  Future<bool> isGranted() async =>
      (await _ch.invokeMethod('isPolicyAccessGranted')) as bool? ?? false;

  Future<void> openSettings() async =>
      _ch.invokeMethod('gotoPolicySettings');

  Future<void> setFilterNone() async =>
      _ch.invokeMethod('setInterruptionFilter', {'mode': 'none'});

  Future<void> setFilterAll() async =>
      _ch.invokeMethod('setInterruptionFilter', {'mode': 'all'});
  Future<String?> getPlatformVersion() {
    return MosquesilenceDndPlatform.instance.getPlatformVersion();
  }
  Future<int> getInterruptionFilter() async {
    // Android values: 0=UNKNOWN, 1=ALL (DND OFF), 2=PRIORITY, 3=NONE, 4=ALARMS
    final res = await MethodChannel('mosquesilence/dnd')
        .invokeMethod('getInterruptionFilter');
    return (res as int?) ?? 0;
  }

}
