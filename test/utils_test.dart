import 'package:fake_process_manager/fake_process_manager.dart';
import 'package:mockito/mockito.dart';
import 'package:path/path.dart' hide equals;
import 'package:process/process.dart';
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

void main() {
  group('utils', () {
    group('in context', () {
      var fakeAndroidSdk = FakeAndroidSDK();
      var mockFileSystem = MockFileSystem();
      var mockFile = MockFile();
      var fakeProcessManager = FakeProcessManager();

      setUp(() {
        fakeAndroidSdk = FakeAndroidSDK();
        mockFileSystem = MockFileSystem();
        mockFile = MockFile();
        fakeProcessManager = FakeProcessManager();
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

      testUsingContext('getIosSimulatorLocale', () {
        when(fs.file(any)).thenReturn(mockFile);
        when(mockFile.existsSync()).thenReturn(false);
        when(fs.path).thenReturn(Context());
        fakeProcessManager.calls = [
          Call('plutil -convert binary1 null', null),
          Call(
              'plutil -convert json -o - /Library/Developer/CoreSimulator/Devices/udid/data/Library/Preferences/.GlobalPreferences.plist',
              ProcessResult(0, 0, '{"AppleLocale":"en_US"}', '')),
        ];
        final result = getIosSimulatorLocale('udid');
        expect(result, 'en_US');
      }, overrides: <Type, Generator>{
        FileSystem: () => mockFileSystem,
        ProcessManager: () => fakeProcessManager,
        Platform: () => FakePlatform(environment: {'HOME': ''})
      });
    });

    group('not in context', () {
      test('findEmulator', () {
        final emulatorName = 'emulator name';
        final emulatorId = '$emulatorName API 123'.replaceAll(' ', '_');
        final expected = DaemonEmulator(
            emulatorId, '$emulatorName version', 'category', DeviceType.android);
        expect(
            findEmulator([expected], emulatorName)!.name, equals(expected.name));
      });
    });
  });
}

class MockFileSystem extends Mock implements FileSystem {}

class MockFile extends Mock implements File {}
