import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'mosquesilence_dnd_method_channel.dart';

abstract class MosquesilenceDndPlatform extends PlatformInterface {
  /// Constructs a MosquesilenceDndPlatform.
  MosquesilenceDndPlatform() : super(token: _token);

  static final Object _token = Object();

  static MosquesilenceDndPlatform _instance = MethodChannelMosquesilenceDnd();

  /// The default instance of [MosquesilenceDndPlatform] to use.
  ///
  /// Defaults to [MethodChannelMosquesilenceDnd].
  static MosquesilenceDndPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [MosquesilenceDndPlatform] when
  /// they register themselves.
  static set instance(MosquesilenceDndPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
