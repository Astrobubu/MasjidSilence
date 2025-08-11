import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'mosquesilence_dnd_platform_interface.dart';

/// An implementation of [MosquesilenceDndPlatform] that uses method channels.
class MethodChannelMosquesilenceDnd extends MosquesilenceDndPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('mosquesilence_dnd');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
