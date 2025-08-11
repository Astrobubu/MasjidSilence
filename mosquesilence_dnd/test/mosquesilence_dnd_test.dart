import 'package:flutter_test/flutter_test.dart';
import 'package:mosquesilence_dnd/mosquesilence_dnd.dart';
import 'package:mosquesilence_dnd/mosquesilence_dnd_platform_interface.dart';
import 'package:mosquesilence_dnd/mosquesilence_dnd_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockMosquesilenceDndPlatform
    with MockPlatformInterfaceMixin
    implements MosquesilenceDndPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final MosquesilenceDndPlatform initialPlatform = MosquesilenceDndPlatform.instance;

  test('$MethodChannelMosquesilenceDnd is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelMosquesilenceDnd>());
  });

  test('getPlatformVersion', () async {
    MosqueSilenceDnd mosquesilenceDndPlugin = MosqueSilenceDnd();
    MockMosquesilenceDndPlatform fakePlatform = MockMosquesilenceDndPlatform();
    MosquesilenceDndPlatform.instance = fakePlatform;

  });
}
