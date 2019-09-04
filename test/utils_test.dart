import 'package:mockito/mockito.dart';
import 'package:screenshots/screenshots.dart';
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
  });
}
