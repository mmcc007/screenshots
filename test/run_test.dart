import 'dart:io';

import 'package:mockito/mockito.dart';
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
        {
          'id': '3b3455019e329e007e67239d9b897148244b5053',
          'name': 'Maurice’s iPhone',
          'platform': 'ios',
          'emulator': false,
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
    },
        skip: false,
        overrides: <Type, Generator>{ProcessManager: () => fakeProcessManager});

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
        Call('adb -s emulator-5554 shell getprop persist.sys.locale',
            ProcessResult(0, 0, 'en-US', '')),
        Call('adb -s emulator-5554 shell getprop persist.sys.locale',
            ProcessResult(0, 0, 'en-US', '')),
        Call('flutter -d emulator-5554 drive example/test_driver/main.dart',
            ProcessResult(0, 0, 'drive output', '')),
        Call('adb -s emulator-5554 shell getprop persist.sys.locale',
            ProcessResult(0, 0, 'en-US', '')),
        Call('adb -s emulator-5554 emu kill', null),
      ];
      fakeProcessManager.calls = calls;

      final devices = [];
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
    },
        skip: false,
        overrides: <Type, Generator>{ProcessManager: () => fakeProcessManager});

    testUsingContext(
        'android and ios run with no started devices or emulators and multiple locales',
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
        - fr-CA
      devices:
        android:
          $emulatorName:
      frame: false
      ''';
      final result =
          await runScreenshots(configStr: configStr, client: mockDaemonClient);
      expect(result, isTrue);
      fakeProcessManager.verifyCalls();
    },
        skip: false,
        overrides: <Type, Generator>{ProcessManager: () => fakeProcessManager});
  });
}

class MockDaemonClient extends Mock implements DaemonClient {}
