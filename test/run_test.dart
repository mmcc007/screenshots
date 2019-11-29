//import 'dart:io';

import 'package:fake_process_manager/fake_process_manager.dart';
import 'package:file/memory.dart';
import 'package:mockito/mockito.dart';
import 'package:platform/platform.dart';
import 'package:process/process.dart';
import 'package:screenshots/src/daemon_client.dart';
import 'package:screenshots/src/run.dart';
import 'package:screenshots/src/screens.dart';
import 'package:test/test.dart';
import 'package:tool_base/tool_base.dart';
import 'package:tool_base_test/tool_base_test.dart';

import 'src/mocks.dart';

main() {
  final stagingDir = '/tmp/screenshots';
  Directory sdkDir;

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

  FakeProcessManager fakeProcessManager;
  MockDaemonClient mockDaemonClient;

  setUp(() async {
    fakeProcessManager = FakeProcessManager(stdinResults: _captureStdin);
    mockDaemonClient = MockDaemonClient();
    when(mockDaemonClient.emulators)
        .thenAnswer((_) => Future.value([daemonEmulator]));
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
//          Call('$adbPath -s emulator-5554 emu avd name',
//              ProcessResult(0, 0, 'Nexus_6P_API_28', '')),
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
//          Call('$adbPath -s emulator-5554 emu avd name',
//              ProcessResult(0, 0, 'Nexus_6P_API_28', '')),
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
      MemoryFileSystem memoryFileSystem;

      setUp(() async {
        memoryFileSystem = MemoryFileSystem();
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

        final result = await screenshots(configStr: configStr);
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
            'plutil -convert json -o - //Library/Developer/CoreSimulator/Devices/$simulatorID/data/Library/Preferences/.GlobalPreferences.plist',
            ProcessResult(0, 0, '{"AppleLocale":"en_US"}', ''));
        final callPlutilFrCA = Call(
            'plutil -convert json -o - //Library/Developer/CoreSimulator/Devices/$simulatorID/data/Library/Preferences/.GlobalPreferences.plist',
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
          Call('plutil -convert binary1 //Library/Developer/CoreSimulator/Devices/$simulatorID/data/Library/Preferences/.GlobalPreferences.plist', null),
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
            'ephemeral': true,
            "emulatorId": "emulator_id",
          },
          {
            'id': '$simulatorID',
            'name': 'User’s iPhone X',
            'platform': 'ios',
            'emulator': true,
            'category': 'mobile',
            'platformType': 'ios',
            'ephemeral': true,
            'model': 'iPhone 5c (GSM)',
          "emulatorId": 'emulatorId',
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

            memoryFileSystem.file('example/test_driver/main.dart').createSync(recursive: true);
            memoryFileSystem.directory('/Library/Developer/CoreSimulator/Devices/$simulatorID/data/Library/Preferences').createSync(recursive: true);

        final screenshots = Screenshots(configStr: configStr);
        final result = await screenshots.run();
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
//            'HOME': LocalPlatform().environment['HOME']
            'HOME': memoryFileSystem.currentDirectory.path
          }
          ..operatingSystem = 'macos',
//        Logger: () => VerboseLogger(StdoutLogger()),
        FileSystem: () => memoryFileSystem,
      });
    });
  });

  group('hack in CI', (){
    final daemonDevice = loadDaemonDevice({
      'id': 'emulator-5554',
      'name': 'Android SDK built for x86',
      'platform': 'android-x86',
//      'platform': 'android-arm', // expect android-x86
      'emulator': true,
//      'emulator': false, // expect true
      'category': 'mobile',
      'platformType': 'android',
      'ephemeral': true,
      'emulatorId': 'Nexus_6P_API_28',
//      'emulatorId': null, // expect Nexus_6P_API_28 (or running avd)
    });

    setUp(() {
      when(mockDaemonClient.devices)
          .thenAnswer((_) => Future.value([daemonDevice]));
    });

    testUsingContext('on android', () async {
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
                orientation: 
                 - Portrait
                 - LandscapeRight
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
//        Call('$adbPath -s emulator-5554 emu avd name',
//            ProcessResult(0, 0, 'Nexus_6P_API_28', '')),
        Call(
            '$adbPath -s emulator-5554 shell settings put system user_rotation 0',
            null),
        Call('flutter -d emulator-5554 drive example/test_driver/main.dart',
            ProcessResult(0, 0, 'drive output', '')),
        Call(
            '$adbPath -s emulator-5554 shell settings put system user_rotation 1',
            null),
        Call('flutter -d emulator-5554 drive example/test_driver/main.dart',
            ProcessResult(0, 0, 'drive output', '')),
      ];
      fakeProcessManager.calls = calls;

      final result = await screenshots(configStr: configStr);
      final BufferLogger logger = context.get<Logger>();

      expect(result, isTrue);
      fakeProcessManager.verifyCalls();
      verify(mockDaemonClient.devices).called(3);
      verify(mockDaemonClient.emulators).called(1);
      expect(logger.errorText, '');
//      expect(logger.statusText, '');
      expect(logger.statusText, isNot(contains('Warning: the locale of a real device cannot be changed.')));
    }, skip: false, overrides: <Type, Generator>{
      DaemonClient: () => mockDaemonClient,
//      FileSystem: () => fs,
      ProcessManager: () => fakeProcessManager,
      Platform: () => FakePlatform.fromPlatform(const LocalPlatform())
        ..environment = {'CI': 'true'},
//        Logger: () => VerboseLogger(StdoutLogger()),
      Logger: () => BufferLogger(),
    });
  });

  group('main image magick', () {
    testUsingContext('is installed on macOS/linux', () async {
      fakeProcessManager.calls = [Call('convert -version', ProcessResult(0, 0, '', ''))];
      final isInstalled = await isImageMagicInstalled();
      expect(isInstalled, isTrue);
      fakeProcessManager.verifyCalls();
    }, overrides: <Type, Generator>{
      ProcessManager: () => fakeProcessManager,
      Platform: () => FakePlatform.fromPlatform(const LocalPlatform())
        ..operatingSystem = 'macos',
    });

    testUsingContext('is installed on windows', () async {
      fakeProcessManager.calls = [Call('magick -version', ProcessResult(0, 0, '', ''))];
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
        Call('magick -version', null, sideEffects: ()=> throw 'exception')
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

  group('run utils', () {
    testUsingContext('change android locale', () {
      String adbPath = initAdbPath();
      final deviceId = 'deviceId';
      final deviceLocale = 'deviceLocale';
      final testLocale = 'testLocale';

      fakeProcessManager.calls = [
        Call(
            '$adbPath -s $deviceId root',
            ProcessResult(
                0, 0, 'adbd cannot run as root in production builds\n', '')),
        Call(
            '$adbPath -s $deviceId shell setprop persist.sys.locale $testLocale ; setprop ctl.restart zygote',
            null),
      ];
      changeAndroidLocale(deviceId, deviceLocale, testLocale);
      fakeProcessManager.verifyCalls();
    }, skip: false, overrides: <Type, Generator>{
      ProcessManager: () => fakeProcessManager,
//      Logger: () => VerboseLogger(StdoutLogger()),
    });

//    testUsingContext('start emulator on CI', () async {
//      final emulatorId = 'emulatorId';
//      final emulatorAvdName = 'emulatorAvdName';
//      final stagingDir = 'stagingDir';
//      String adbPath = initAdbPath();
//
//      fakeProcessManager.calls = [
//        Call('$stagingDir/resources/script/android-wait-for-emulator', null),
//        Call(
//            '$adbPath devices',
//            ProcessResult(
//                0, 0, 'List of devices attached\n$emulatorId	device\n', '')),
//        Call('$adbPath -s $emulatorId emu avd name',
//            ProcessResult(0, 0, '$emulatorAvdName', '')),
//      ];
//      await startEmulator(null, emulatorId, stagingDir);
//      fakeProcessManager.verifyCalls();
//    }, skip: false, overrides: <Type, Generator>{
//      ProcessManager: () => fakeProcessManager,
//      Platform: () => FakePlatform.fromPlatform(const LocalPlatform())
//        ..environment = {
//          'CI': 'true',
//          'ANDROID_HOME': 'android_home',
//        },
////      Logger: () => VerboseLogger(StdoutLogger()),
//    });

    test('find running device', () async {
      final emulatorId = 'emulator-5554';
      final emulatorAvdName = 'Nexus_6P_API_28';
      final deviceName = 'Nexus 6P';
//      String adbPath = initAdbPath();
//
//      fakeProcessManager.calls = [
//        Call('$adbPath -s $emulatorId emu avd name',
//            ProcessResult(0, 0, '$emulatorAvdName', '')),
//      ];

      final device = loadDaemonDevice({
        'id': '$emulatorId',
        'name': 'sdk phone armv7',
        'platform': 'android-arm',
        'emulator': true,
        'category': 'mobile',
        'platformType': 'android',
        'ephemeral': true,
        'emulatorId':emulatorAvdName,
      });

      final emulator = loadDaemonEmulator({
        'id': '$emulatorAvdName',
        'name': '${emulatorAvdName.replaceAll('_', ' ')}',
        'category': 'mobile',
        'platformType': 'android'
      });
      final deviceFound = findRunningDevice([device], [emulator], deviceName);
      expect(deviceFound, equals(device));
//      fakeProcessManager.verifyCalls();
//    }, skip: false, overrides: <Type, Generator>{
//      ProcessManager: () => fakeProcessManager,
//      Platform: () => FakePlatform.fromPlatform(const LocalPlatform())
//        ..environment = {
//          'CI': 'true',
//          'ANDROID_HOME': 'android_home',
//        },
//      Logger: () => VerboseLogger(StdoutLogger()),
    });

    testUsingContext('multiple tests', () async {
      final deviceName = 'device name';
      final deviceId='deviceId';
      final test1='test_driver/main.dart';
      final test2='test_driver/main2.dart';
      final configStr = '''
        tests:
          - $test1
          - $test2
        staging: /tmp/screenshots
        locales:
          - en-US
        devices:
          ios:
            $deviceName:
        frame: false
      ''';
      final screenshots = Screenshots(configStr: configStr);
      screenshots.screens = Screens();
      await screenshots.screens.init();
      fakeProcessManager.calls = [
        Call('flutter -d $deviceId drive $test1', null),
        Call('flutter -d $deviceId drive $test2', null),
      ];
      final result = await screenshots.runProcessTests(
        deviceName,
        'locale',
        null,
        getDeviceType(screenshots.config, deviceName),
        deviceId,
      );
      expect(result, isNull);
      fakeProcessManager.verifyCalls();
    }, skip: false, overrides: <Type, Generator>{
      ProcessManager: () => fakeProcessManager,
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
