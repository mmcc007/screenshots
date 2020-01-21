import 'package:fake_process_manager/fake_process_manager.dart';
import 'package:mockito/mockito.dart';
import 'package:path/path.dart' hide equals;
import 'package:process/process.dart';
import 'package:screenshots/src/daemon_client.dart';
import 'package:screenshots/src/utils.dart';
import 'package:test/test.dart';
import 'package:tool_base/tool_base.dart';
import 'package:tool_base_test/tool_base_test.dart';
import 'package:tool_mobile/tool_mobile.dart';

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
      FileSystem mockFileSystem;
      File mockFile;
      FakeProcessManager fakeProcessManager;

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
        final xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<string>en_US</string>
</plist>        
        ''';
        when(fs.file(any)).thenReturn(mockFile);
        when(mockFile.existsSync()).thenReturn(false);
        when(fs.path).thenReturn(Context());
        fakeProcessManager.calls = [
          Call('plutil -convert binary1 null', null),
          Call(
              'plutil -extract AppleLocale xml1 -o - null',
              ProcessResult(0, 0, xml, '')),
        ];
        final result = getIosSimulatorLocale('udid');
        expect(result, 'en_US');
        fakeProcessManager.verifyCalls();
      }, overrides: <Type, Generator>{
        FileSystem: () => mockFileSystem,
        ProcessManager: () => fakeProcessManager,
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

class MockFileSystem extends Mock implements FileSystem {}

class MockFile extends Mock implements File {}
