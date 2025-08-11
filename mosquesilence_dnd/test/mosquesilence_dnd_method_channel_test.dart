import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosquesilence_dnd/mosquesilence_dnd_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelMosquesilenceDnd platform = MethodChannelMosquesilenceDnd();
  const MethodChannel channel = MethodChannel('mosquesilence_dnd');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return '42';
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
