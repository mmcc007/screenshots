import 'dart:io';

import 'package:mockito/mockito.dart';
import 'package:platform/platform.dart';
import 'package:process/process.dart';
import 'package:screenshots/src/base/context.dart';
import 'package:screenshots/src/daemon_client.dart';
import 'package:screenshots/src/run.dart';
import 'package:test/test.dart';

import 'src/context.dart';
import 'src/fake_process_manager.dart';

main() {
  FakeProcessManager fakeProcessManager;
  MockDaemonClient mockDaemonClient;
  final List<String> stdinCaptured = <String>[];

  void _captureStdin(String item) {
    stdinCaptured.add(item);
  }

  setUp(() async {
    fakeProcessManager = FakeProcessManager(stdinResults: _captureStdin);
    mockDaemonClient = MockDaemonClient();
  });

  group('run', () {
    testUsingContext(
        'android only run with running emulator and no locales and no frames',
        () async {
      final emulatorName = 'Nexus 6P';
      // fake process responses
      final List<Call> calls = [
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
        Call('adb -s emulator-5554 emu avd name',
            ProcessResult(0, 0, 'Nexus_6P_API_28', '')),
        Call('adb -s emulator-5554 shell getprop persist.sys.locale',
            ProcessResult(0, 0, 'en-US', '')),
        Call('adb -s emulator-5554 shell getprop persist.sys.locale',
            ProcessResult(0, 0, 'en-US', '')),
        Call('flutter -d emulator-5554 drive example/test_driver/main.dart',
            ProcessResult(0, 0, 'drive output', '')),
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
      ];
      final emulators = [
        {
          'id': 'Nexus_6P_API_28',
          'name': 'Nexus 6P',
          'category': 'mobile',
          'platformType': 'android'
        },
      ];
      when(mockDaemonClient.devices).thenAnswer((_) => Future.value(devices));
      when(mockDaemonClient.emulators)
          .thenAnswer((_) => Future.value(emulators));

      // screenshots config
      final configStr = '''
      tests:
        - example/test_driver/main.dart
      staging: /tmp/screenshots
      locales:
        - en-US
      devices:
        android:
          $emulatorName:
      frame: false
      ''';
      final result =
          await runScreenshots(configStr: configStr, client: mockDaemonClient);
      expect(result, isTrue);
      fakeProcessManager.verifyCalls();
    }, skip: false, overrides: <Type, Generator>{
      ProcessManager: () => fakeProcessManager,
      Platform: () => FakePlatform.fromPlatform(const LocalPlatform())
        ..environment = {'CI': 'false'},
    });

    testUsingContext(
        'android only run with no running devices or emulators and no locales',
        () async {
      final emulatorName = 'Nexus 6P';
      // fake process responses
      final List<Call> calls = [
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
        Call('adb -s emulator-5554 emu avd name',
            ProcessResult(0, 0, 'Nexus_6P_API_28', '')),
        Call('adb -s emulator-5554 shell getprop persist.sys.locale',
            ProcessResult(0, 0, 'en-US', '')),
        Call('adb -s emulator-5554 shell getprop persist.sys.locale',
            ProcessResult(0, 0, 'en-US', '')),
        Call('flutter -d emulator-5554 drive example/test_driver/main.dart',
            ProcessResult(0, 0, 'drive output', '')),
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
      ];
      final devicesSequence = [[]];
      int devicesSeqIndex = 0;
      final emulators = [
        {
          'id': 'Nexus_6P_API_28',
          'name': 'Nexus 6P',
          'category': 'mobile',
          'platformType': 'android'
        },
      ];
      when(mockDaemonClient.devices).thenAnswer((_) => Future.value(devices));
      when(mockDaemonClient.emulators)
          .thenAnswer((_) => Future.value(emulators));
      when(mockDaemonClient.launchEmulator('Nexus_6P_API_28'))
          .thenAnswer((_) => Future.value('emulator-5554'));
      when(mockDaemonClient.waitForEvent(EventType.deviceRemoved))
          .thenAnswer((_) => Future.value({'id': 'emulator-5554'}));

      // screenshots config
      final configStr = '''
      tests:
        - example/test_driver/main.dart
      staging: /tmp/screenshots
      locales:
        - en-US
      devices:
        android:
          $emulatorName:
      frame: true
      ''';
      final result =
          await runScreenshots(configStr: configStr, client: mockDaemonClient);
      expect(result, isTrue);
      fakeProcessManager.verifyCalls();
    }, skip: false, overrides: <Type, Generator>{
      ProcessManager: () => fakeProcessManager,
      Platform: () => FakePlatform.fromPlatform(const LocalPlatform())
        ..environment = {'CI': 'false'},
    });

    testUsingContext(
        'android and ios run with no started devices or emulators and multiple locales',
        () async {
      final emulatorName = 'Nexus 6P';
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
                        "udid" : "6B3B1AD9-EFD3-49AB-9CE9-D43CE1A47446"
                      }
                    ]
                  }
                }
                ''',
              ''));
      final List<Call> calls = [
        callListIosDevices,
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
        Call('adb -s emulator-5554 shell getprop persist.sys.locale',
            ProcessResult(0, 0, 'en-US', '')),
        Call('adb -s emulator-5554 shell getprop persist.sys.locale',
            ProcessResult(0, 0, 'en-US', '')),
        Call('flutter -d emulator-5554 drive example/test_driver/main.dart',
            ProcessResult(0, 0, 'drive output', '')),
        Call('adb -s emulator-5554 shell getprop persist.sys.locale',
            ProcessResult(0, 0, 'en-US', '')),
        Call('adb -s emulator-5554 root', null),
        Call(
            'adb -s emulator-5554 shell setprop persist.sys.locale fr-CA ; setprop ctl.restart zygote',
            null),
        Call('adb -s emulator-5554 logcat -c', null),
        Call(
            'adb -s emulator-5554 logcat -b main *:S ContactsDatabaseHelper:I ContactsProvider:I -e fr_CA',
            ProcessResult(
                0,
                0,
                '08-28 14:25:11.994  5294  5417 I ContactsProvider: Locale has changed from [en_US] to [fr_CA]',
                '')),
        Call('flutter -d emulator-5554 drive example/test_driver/main.dart',
            null),
        Call('adb -s emulator-5554 shell getprop persist.sys.locale',
            ProcessResult(0, 0, 'fr-CA', '')),
        Call('adb -s emulator-5554 root', null),
        Call(
            'adb -s emulator-5554 shell setprop persist.sys.locale en-US ; setprop ctl.restart zygote',
            null),
        Call('adb -s emulator-5554 logcat -c', null),
        Call(
            'adb -s emulator-5554 logcat -b main *:S ContactsDatabaseHelper:I ContactsProvider:I -e en_US',
            ProcessResult(
                0,
                0,
                '08-28 14:25:11.994  5294  5417 I ContactsProvider: Locale has changed from [fr_CA] to [en_US]',
                '')),
        Call('adb -s emulator-5554 emu kill', null),
        callListIosDevices,
        Call(
            'plutil -convert json -o - /Users/jenkins/Library/Developer/CoreSimulator/Devices/6B3B1AD9-EFD3-49AB-9CE9-D43CE1A47446/data/Library/Preferences/.GlobalPreferences.plist',
            ProcessResult(0, 0, '{"AppleLocale":"en_US"}', '')),
        Call('xcrun simctl boot 6B3B1AD9-EFD3-49AB-9CE9-D43CE1A47446', null),
        Call(
            'plutil -convert json -o - /Users/jenkins/Library/Developer/CoreSimulator/Devices/6B3B1AD9-EFD3-49AB-9CE9-D43CE1A47446/data/Library/Preferences/.GlobalPreferences.plist',
            ProcessResult(0, 0, '{"AppleLocale":"en_US"}', '')),
        Call(
            'plutil -convert json -o - /Users/jenkins/Library/Developer/CoreSimulator/Devices/6B3B1AD9-EFD3-49AB-9CE9-D43CE1A47446/data/Library/Preferences/.GlobalPreferences.plist',
            ProcessResult(0, 0, '{"AppleLocale":"en_US"}', '')),
        Call(
            'flutter -d 6B3B1AD9-EFD3-49AB-9CE9-D43CE1A47446 drive example/test_driver/main.dart',
            null),
        Call(
            'plutil -convert json -o - /Users/jenkins/Library/Developer/CoreSimulator/Devices/6B3B1AD9-EFD3-49AB-9CE9-D43CE1A47446/data/Library/Preferences/.GlobalPreferences.plist',
            ProcessResult(0, 0, '{"AppleLocale":"en_US"}', '')),
        Call(
            '/tmp/screenshots/resources/script/simulator-controller 6B3B1AD9-EFD3-49AB-9CE9-D43CE1A47446 locale fr-CA',
            null),
        Call(
            'xcrun simctl shutdown 6B3B1AD9-EFD3-49AB-9CE9-D43CE1A47446', null),
        Call('xcrun simctl boot 6B3B1AD9-EFD3-49AB-9CE9-D43CE1A47446', null),
        Call(
            'flutter -d 6B3B1AD9-EFD3-49AB-9CE9-D43CE1A47446 drive example/test_driver/main.dart',
            null),
        Call(
            'plutil -convert json -o - /Users/jenkins/Library/Developer/CoreSimulator/Devices/6B3B1AD9-EFD3-49AB-9CE9-D43CE1A47446/data/Library/Preferences/.GlobalPreferences.plist',
            ProcessResult(0, 0, '{"AppleLocale":"fr-CA"}', '')),
        Call(
            '/tmp/screenshots/resources/script/simulator-controller 6B3B1AD9-EFD3-49AB-9CE9-D43CE1A47446 locale en_US',
            null),
        Call(
            'xcrun simctl shutdown 6B3B1AD9-EFD3-49AB-9CE9-D43CE1A47446', null),
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
          'id': '3b3455019e329e007e67239d9b897148244b5053',
          'name': 'Maurice’s iPhone',
          'platform': 'ios',
          'emulator': false,
          'category': 'mobile',
          'platformType': 'ios',
          'ephemeral': true,
          'model': 'iPhone 5c (GSM)'
        },
        {
          'id': '6B3B1AD9-EFD3-49AB-9CE9-D43CE1A47446',
          'name': 'User’s iPhone X',
          'platform': 'ios',
          'emulator': true,
          'category': 'mobile',
          'platformType': 'ios',
          'ephemeral': true,
          'model': 'iPhone 5c (GSM)'
        }
      ];

      final emulators = [
        {
          'id': 'Nexus_6P_API_28',
          'name': 'Nexus 6P',
          'category': 'mobile',
          'platformType': 'android'
        },
        {
          'id': 'apple_ios_simulator',
          'name': 'iOS Simulator',
          'category': 'mobile',
          'platformType': 'ios'
        }
      ];

      final devicesResponses = [[], devices, devices];
      when(mockDaemonClient.devices)
          .thenAnswer((_) => Future.value(devicesResponses.removeAt(0)));
      when(mockDaemonClient.emulators)
          .thenAnswer((_) => Future.value(emulators));
      when(mockDaemonClient.launchEmulator('Nexus_6P_API_28'))
          .thenAnswer((_) => Future.value('emulator-5554'));
      when(mockDaemonClient.waitForEvent(EventType.deviceRemoved))
          .thenAnswer((_) => Future.value({'id': 'emulator-5554'}));

      // screenshots config
      final configStr = '''
      tests:
        - example/test_driver/main.dart
      staging: /tmp/screenshots
      locales:
        - en-US
        - fr-CA
      devices:
        android:
          $emulatorName:
        ios:
          iPhone X:
      frame: false
      ''';
      final result =
          await runScreenshots(configStr: configStr, client: mockDaemonClient);
      expect(result, isTrue);
      fakeProcessManager.verifyCalls();
    }, skip: false, overrides: <Type, Generator>{
      ProcessManager: () => fakeProcessManager,
      Platform: () => FakePlatform.fromPlatform(const LocalPlatform())
        ..environment = {'CI': 'false'},
    });
  });
}

class MockDaemonClient extends Mock implements DaemonClient {}
