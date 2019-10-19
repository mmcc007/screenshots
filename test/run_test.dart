import 'dart:io';

import 'package:file/file.dart';
import 'package:mockito/mockito.dart';
import 'package:platform/platform.dart';
import 'package:process/process.dart';
import 'package:screenshots/src/daemon_client.dart';
import 'package:screenshots/src/run.dart';
import 'package:test/test.dart';
import 'package:tool_base/tool_base.dart';

import 'src/common_tools.dart';
import 'src/context.dart';
import 'src/fake_process_manager.dart';
import 'src/mocks.dart';

main() {
  final stagingDir = '/tmp/screenshots';
//  MemoryFileSystem fs;
  Directory sdkDir;

  FakeProcessManager fakeProcessManager;
  MockDaemonClient mockDaemonClient;
  final List<String> stdinCaptured = <String>[];

  void _captureStdin(String item) {
    stdinCaptured.add(item);
  }

  final unpackScriptsCalls = [
    Call(
        'chmod u+x /tmp/screenshots/resources/script/android-wait-for-emulator',
        null),
    Call(
        'chmod u+x /tmp/screenshots/resources/script/android-wait-for-emulator-to-stop',
        null),
    Call('chmod u+x /tmp/screenshots/resources/script/simulator-controller',
        null),
    Call('chmod u+x /tmp/screenshots/resources/script/sim_orientation.scpt',
        null),
  ];

  final daemonEmulator = loadDaemonEmulator({
    'id': 'Nexus_6P_API_28',
    'name': 'Nexus 6P',
    'category': 'mobile',
    'platformType': 'android'
  });

  setUp(() async {
//    fs = MemoryFileSystem();
    fakeProcessManager = FakeProcessManager(stdinResults: _captureStdin);
    mockDaemonClient = MockDaemonClient();
    when(mockDaemonClient.emulators)
        .thenAnswer((_) => Future.value([daemonEmulator]));

    // create screenshot dir
//    fs
//        .directory('$stagingDir/$kTestScreenshotsDir')
//        .createSync(recursive: true);
  });

  tearDown(() {
    if (sdkDir != null) {
      tryToDelete(sdkDir);
      sdkDir = null;
    }
  });

  group('run', () {
    group('with one running android emulator only', () {
      final daemonDevice = loadDaemonDevice({
        'id': 'emulator-5554',
        'name': 'Android SDK built for x86',
        'platform': 'android-x86',
        'emulator': true,
        'category': 'mobile',
        'platformType': 'android',
        'ephemeral': true,
        'emulatorId': 'Nexus_6P_API_28',
      });

      setUp(() {
        when(mockDaemonClient.devices)
            .thenAnswer((_) => Future.value([daemonDevice]));
      });

      testUsingContext(', android only run, no frames, no locales', () async {
        final emulatorName = 'Nexus 6P';
        // screenshots config
        final configStr = '''
          tests:
            - example/test_driver/main.dart
          staging: $stagingDir
          locales:
            - en-US
          devices:
            android:
              $emulatorName:
          frame: false
      ''';
        String adbPath = initAdbPath();
        // fake process responses
        final List<Call> calls = [
          ...unpackScriptsCalls,
          Call('$adbPath -s emulator-5554 emu avd name',
              ProcessResult(0, 0, 'Nexus_6P_API_28', '')),
          Call('$adbPath -s emulator-5554 shell getprop persist.sys.locale',
              ProcessResult(0, 0, 'en-US', '')),
          Call('$adbPath -s emulator-5554 shell getprop persist.sys.locale',
              ProcessResult(0, 0, 'en-US', '')),
          Call('flutter -d emulator-5554 drive example/test_driver/main.dart',
              ProcessResult(0, 0, 'drive output', '')),
        ];
        fakeProcessManager.calls = calls;

        final result = await screenshots(configStr: configStr);
        expect(result, isTrue);
        fakeProcessManager.verifyCalls();
        verify(mockDaemonClient.devices).called(1);
        verify(mockDaemonClient.emulators).called(1);
      }, skip: false, overrides: <Type, Generator>{
        DaemonClient: () => mockDaemonClient,
//      FileSystem: () => fs,
        ProcessManager: () => fakeProcessManager,
        Platform: () => FakePlatform.fromPlatform(const LocalPlatform())
          ..environment = {'CI': 'false'},
//        Logger: () => VerboseLogger(StdoutLogger()),
      });

      testUsingContext(
          ', android only run, no frames, no locales, change orientation',
          () async {
        final emulatorName = 'Nexus 6P';
        // screenshots config
        final configStr = '''
          tests:
            - example/test_driver/main.dart
          staging: $stagingDir
          locales:
            - en-US
          devices:
            android:
              $emulatorName:
                orientation: LandscapeRight
          frame: false
      ''';
        String adbPath = initAdbPath();
        // fake process responses
        final List<Call> calls = [
          ...unpackScriptsCalls,
          Call('$adbPath -s emulator-5554 emu avd name',
              ProcessResult(0, 0, 'Nexus_6P_API_28', '')),
          Call('$adbPath -s emulator-5554 shell getprop persist.sys.locale',
              ProcessResult(0, 0, 'en-US', '')),
          Call('$adbPath -s emulator-5554 shell getprop persist.sys.locale',
              ProcessResult(0, 0, 'en-US', '')),
          Call(
              '$adbPath -s emulator-5554 shell settings put system user_rotation 1',
              null),
          Call('flutter -d emulator-5554 drive example/test_driver/main.dart',
              ProcessResult(0, 0, 'drive output', '')),
        ];
        fakeProcessManager.calls = calls;

        final result = await screenshots(configStr: configStr);
        expect(result, isTrue);
        fakeProcessManager.verifyCalls();
        verify(mockDaemonClient.devices).called(2);
        verify(mockDaemonClient.emulators).called(1);
      }, skip: false, overrides: <Type, Generator>{
        DaemonClient: () => mockDaemonClient,
//      FileSystem: () => fs,
        ProcessManager: () => fakeProcessManager,
        Platform: () => FakePlatform.fromPlatform(const LocalPlatform())
          ..environment = {'CI': 'false'},
//        Logger: () => VerboseLogger(StdoutLogger()),
      });
    });

    group('with no devices, emulators or simulators', () {
      testUsingContext(', android only run, no frames, no locales', () async {
        final emulatorName = 'Nexus 6P';
        // screenshots config
        final configStr = '''
      tests:
        - example/test_driver/main.dart
      staging: $stagingDir
      locales:
        - en-US
      devices:
        android:
          $emulatorName:
      frame: false
      ''';
        String adbPath = initAdbPath();

        // fake process responses
        final List<Call> calls = [
          ...unpackScriptsCalls,
          Call('$adbPath -s emulator-5554 shell getprop persist.sys.locale',
              ProcessResult(0, 0, 'en-US', '')),
          Call('$adbPath -s emulator-5554 shell getprop persist.sys.locale',
              ProcessResult(0, 0, 'en-US', '')),
          Call('flutter -d emulator-5554 drive example/test_driver/main.dart',
              ProcessResult(0, 0, 'drive output', '')),
          Call('$adbPath -s emulator-5554 shell getprop persist.sys.locale',
              ProcessResult(0, 0, 'en-US', '')),
          Call('$adbPath -s emulator-5554 emu kill', null),
        ];
        fakeProcessManager.calls = calls;

        when(mockDaemonClient.devices).thenAnswer((_) => Future.value([]));
        when(mockDaemonClient.launchEmulator('Nexus_6P_API_28'))
            .thenAnswer((_) => Future.value('emulator-5554'));
        when(mockDaemonClient.waitForEvent(EventType.deviceRemoved))
            .thenAnswer((_) => Future.value({'id': 'emulator-5554'}));

        final result = await screenshots(configStr: configStr, verbose: true);
        expect(result, isTrue);
        fakeProcessManager.verifyCalls();
        verify(mockDaemonClient.devices).called(1);
        verify(mockDaemonClient.emulators).called(1);
        verify(mockDaemonClient.launchEmulator('Nexus_6P_API_28')).called(1);
        verify(mockDaemonClient.waitForEvent(EventType.deviceRemoved))
            .called(1);
      }, skip: false, overrides: <Type, Generator>{
        DaemonClient: () => mockDaemonClient,
        ProcessManager: () => fakeProcessManager,
        Platform: () => FakePlatform.fromPlatform(const LocalPlatform())
          ..environment = {'CI': 'false'},
//        Logger: () => VerboseLogger(StdoutLogger()),
      });

      testUsingContext(
          ', android and ios run, no frames, multiple locales, orientation',
          () async {
        final emulatorName = 'Nexus 6P';
        // screenshots config
        final configStr = '''
          tests:
            - example/test_driver/main.dart
          staging: $stagingDir
          locales:
            - en-US
            - fr-CA
          devices:
            android:
              $emulatorName:
                orientation: LandscapeRight
            ios:
              iPhone X:
                orientation: LandscapeRight
          frame: false
      ''';
        final simulatorID = '6B3B1AD9-EFD3-49AB-9CE9-D43CE1A47446';

        // fake process responses
        final callListIosDevices = Call(
            'xcrun simctl list devices --json',
            ProcessResult(
                0,
                0,
                '''
                {
                  "devices" : {
                    "iOS 11.2" : [
                      {
                        "state" : "Shutdown",
                        "availability" : "(available)",
                        "name" : "iPhone 7 Plus",
                        "udid" : "1DD6DBF1-846F-4644-8E97-76175788B9A5"
                      }
                    ],
                    "iOS 11.1" : [
                      {
                        "state" : "Shutdown",
                        "availability" : "(available)",
                        "name" : "iPhone X",
                        "udid" : "$simulatorID"
                      }
                    ]
                  }
                }
                ''',
                ''));
        final callPlutilEnUS = Call(
            'plutil -convert json -o - ${LocalPlatform().environment['HOME']}/Library/Developer/CoreSimulator/Devices/$simulatorID/data/Library/Preferences/.GlobalPreferences.plist',
            ProcessResult(0, 0, '{"AppleLocale":"en_US"}', ''));
        final callPlutilFrCA = Call(
            'plutil -convert json -o - ${LocalPlatform().environment['HOME']}/Library/Developer/CoreSimulator/Devices/$simulatorID/data/Library/Preferences/.GlobalPreferences.plist',
            ProcessResult(0, 0, '{"AppleLocale":"fr_CA"}', ''));
        String adbPath = initAdbPath();
        final List<Call> calls = [
          callListIosDevices,
          ...unpackScriptsCalls,
          Call('$adbPath -s emulator-5554 shell getprop persist.sys.locale',
              ProcessResult(0, 0, 'en-US', '')),
          Call('$adbPath -s emulator-5554 shell getprop persist.sys.locale',
              ProcessResult(0, 0, 'en-US', '')),
          Call(
              '$adbPath -s emulator-5554 shell settings put system user_rotation 1',
              null),
          Call('flutter -d emulator-5554 drive example/test_driver/main.dart',
              ProcessResult(0, 0, 'drive output', '')),
          Call('$adbPath -s emulator-5554 shell getprop persist.sys.locale',
              ProcessResult(0, 0, 'en-US', '')),
          Call('$adbPath -s emulator-5554 root', null),
          Call(
              '$adbPath -s emulator-5554 shell setprop persist.sys.locale fr-CA ; setprop ctl.restart zygote',
              null),
          Call('$adbPath -s emulator-5554 logcat -c', null),
          Call(
              '$adbPath -s emulator-5554 logcat -b main *:S ContactsDatabaseHelper:I ContactsProvider:I -e fr_CA',
              ProcessResult(
                  0,
                  0,
                  '08-28 14:25:11.994  5294  5417 I ContactsProvider: Locale has changed from [en_US] to [fr_CA]',
                  '')),
          Call(
              '$adbPath -s emulator-5554 shell settings put system user_rotation 1',
              null),
          Call('flutter -d emulator-5554 drive example/test_driver/main.dart',
              null),
          Call('$adbPath -s emulator-5554 shell getprop persist.sys.locale',
              ProcessResult(0, 0, 'fr-CA', '')),
          Call('$adbPath -s emulator-5554 root', null),
          Call(
              '$adbPath -s emulator-5554 shell setprop persist.sys.locale en-US ; setprop ctl.restart zygote',
              null),
          Call('$adbPath -s emulator-5554 logcat -c', null),
          Call(
              '$adbPath -s emulator-5554 logcat -b main *:S ContactsDatabaseHelper:I ContactsProvider:I -e en_US',
              ProcessResult(
                  0,
                  0,
                  '08-28 14:25:11.994  5294  5417 I ContactsProvider: Locale has changed from [fr_CA] to [en_US]',
                  '')),
          Call('$adbPath -s emulator-5554 emu kill', null),
          callListIosDevices,
          callPlutilEnUS,
          Call('xcrun simctl boot $simulatorID', null),
          callPlutilEnUS,
          callPlutilEnUS,
          Call(
              'osascript /tmp/screenshots/resources/script/sim_orientation.scpt Landscape Right',
              null),
          Call('flutter -d $simulatorID drive example/test_driver/main.dart',
              null),
          callPlutilEnUS,
          Call(
              '/tmp/screenshots/resources/script/simulator-controller $simulatorID locale fr-CA',
              null),
          Call('xcrun simctl shutdown $simulatorID', null),
          Call('xcrun simctl boot $simulatorID', null),
          Call(
              'osascript /tmp/screenshots/resources/script/sim_orientation.scpt Landscape Right',
              null),
          Call('flutter -d $simulatorID drive example/test_driver/main.dart',
              null),
          callPlutilFrCA,
          Call(
              '/tmp/screenshots/resources/script/simulator-controller $simulatorID locale en_US',
              null),
          Call('xcrun simctl shutdown $simulatorID', null),
        ];
        fakeProcessManager.calls = calls;

        final devices = [
          {
            'id': 'emulator-5554',
            'name': 'Android SDK built for x86',
            'platform': 'android-x86',
            'emulator': true,
            'category': 'mobile',
            'platformType': 'android',
            'ephemeral': true
          },
          {
            'id': '$simulatorID',
            'name': 'User’s iPhone X',
            'platform': 'ios',
            'emulator': true,
            'category': 'mobile',
            'platformType': 'ios',
            'ephemeral': true,
            'model': 'iPhone 5c (GSM)'
          }
        ];
        final daemonDevices =
            devices.map((device) => loadDaemonDevice(device)).toList();

        final List<List<DaemonDevice>> devicesResponses = [
          [],
          daemonDevices,
          daemonDevices,
          daemonDevices,
          daemonDevices,
          daemonDevices,
          daemonDevices,
        ];

        when(mockDaemonClient.devices)
            .thenAnswer((_) => Future.value(devicesResponses.removeAt(0)));
        when(mockDaemonClient.launchEmulator('Nexus_6P_API_28'))
            .thenAnswer((_) => Future.value('emulator-5554'));
        when(mockDaemonClient.waitForEvent(EventType.deviceRemoved))
            .thenAnswer((_) => Future.value({'id': 'emulator-5554'}));

        final result = await runScreenshots(configStr: configStr);
        expect(result, isTrue);
        fakeProcessManager.verifyCalls();
        verify(mockDaemonClient.devices).called(7);
        verify(mockDaemonClient.emulators).called(1);
        verify(mockDaemonClient.launchEmulator('Nexus_6P_API_28')).called(1);
        verify(mockDaemonClient.waitForEvent(EventType.deviceRemoved))
            .called(1);
      }, skip: false, overrides: <Type, Generator>{
        DaemonClient: () => mockDaemonClient,
        ProcessManager: () => fakeProcessManager,
        Platform: () => FakePlatform.fromPlatform(const LocalPlatform())
          ..environment = {
            'CI': 'false',
            'HOME': LocalPlatform().environment['HOME']
          }
          ..operatingSystem = 'macos',
//        Logger: () => VerboseLogger(StdoutLogger()),
      });
    });
  });

  group('image magick', () {
    testUsingContext('is installed on macOS/linux', () async {
      fakeProcessManager.calls = [Call('convert -version', null)];
      final isInstalled = await isImageMagicInstalled();
      expect(isInstalled, isTrue);
      fakeProcessManager.verifyCalls();
    }, overrides: <Type, Generator>{
      ProcessManager: () => fakeProcessManager,
      Platform: () => FakePlatform.fromPlatform(const LocalPlatform())
        ..operatingSystem = 'macos',
    });

    testUsingContext('is installed on windows', () async {
      fakeProcessManager.calls = [Call('magick -version', null)];
      final isInstalled = await isImageMagicInstalled();
      expect(isInstalled, isTrue);
      fakeProcessManager.verifyCalls();
    }, overrides: <Type, Generator>{
      ProcessManager: () => fakeProcessManager,
      Platform: () => FakePlatform.fromPlatform(const LocalPlatform())
        ..operatingSystem = 'windows',
    });

    testUsingContext('is not installed on windows', () async {
      fakeProcessManager.calls = [
        Call('magick -version', ProcessResult(0, 1, '', ''))
      ];
      final isInstalled = await isImageMagicInstalled();
      expect(isInstalled, isFalse);
      fakeProcessManager.verifyCalls();
    }, overrides: <Type, Generator>{
      ProcessManager: () => fakeProcessManager,
      Platform: () => FakePlatform.fromPlatform(const LocalPlatform())
        ..operatingSystem = 'windows',
    });
  });
}

String initAdbPath() {
  final sdkDir = MockAndroidSdk.createSdkDirectory();
  Config.instance.setValue('android-sdk', sdkDir.path);
  final adbPath = '${sdkDir.path}/platform-tools/adb';
  return adbPath;
}

class MockDaemonClient extends Mock implements DaemonClient {}
