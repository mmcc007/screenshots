import 'package:mockito/mockito.dart';
import 'package:screenshots/screenshots.dart';
import 'package:screenshots/src/daemon_client.dart';
import 'package:screenshots/src/utils.dart';
import 'package:test/test.dart';
import 'package:tool_base/tool_base.dart';
import 'package:tool_mobile/tool_mobile.dart';

import 'src/context.dart';

class FakeAndroidSDK extends Fake implements AndroidSdk {
  @override
  String get adbPath => 'path to adb';

  @override
  String get emulatorPath => 'path to emulator';
}

main() {
  group('utils', () {
    group('in context', () {
      FakeAndroidSDK fakeAndroidSdk;

      setUp(() {
        fakeAndroidSdk = FakeAndroidSDK();
      });

      testUsingContext('get adb path', () async {
        final adbPathFound = await isAdbPath();
        expect(adbPathFound, isTrue);
      }, overrides: <Type, Generator>{
        AndroidSdk: () => fakeAndroidSdk,
      });

      testUsingContext('get emulator path', () async {
        final emulatorPathFound = await isEmulatorPath();
        expect(emulatorPathFound, isTrue);
      }, overrides: <Type, Generator>{
        AndroidSdk: () => fakeAndroidSdk,
      });

      testUsingContext('with null CI env', () {
        expect(isCI(), isFalse);
      }, overrides: <Type, Generator>{
        Platform: () => FakePlatform(environment: {}),
      });
    });

    group('not in context', () {
      test('findEmulator', () {
        final emulatorName = 'emulator name';
        final emulatorId = '$emulatorName API 123'.replaceAll(' ', '_');
        final expected = DaemonEmulator(
            emulatorId, '$emulatorName version', 'category', 'platformType');
        expect(
            findEmulator([expected], emulatorName).name, equals(expected.name));
      });
    });
  });
}
