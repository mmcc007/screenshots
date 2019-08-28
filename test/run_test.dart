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
    testUsingContext('run', () async {
      final emulatorName = 'Nexus 6P';
      // fake process responses
      final Map<String, List<ProcessResult>> processCalls = {
        'sh -c ios-deploy -c || echo "no attached devices"': [
          ProcessResult(0, 0, 'no attached devices', ''),
        ],
        'chmod u+x /tmp/screenshots/resources/script/android-wait-for-emulator':
            null,
        'chmod u+x /tmp/screenshots/resources/script/android-wait-for-emulator-to-stop':
            null,
        'chmod u+x /tmp/screenshots/resources/script/simulator-controller':
            null,
        'chmod u+x /tmp/screenshots/resources/script/sim_orientation.scpt':
            null,
        'emulator -list-avds': [
          ProcessResult(0, 0, '$emulatorName\nanother emulator', '')
        ],
        'xcrun simctl list devices --json': [
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
              ''),
        ],
        'adb -s emulator-5554 emu avd name': [
          ProcessResult(0, 0, 'Nexus_6P_API_28', '')
        ],
        'adb -s emulator-5554 shell getprop persist.sys.locale': [
          ProcessResult(0, 0, 'en-US', ''),
          ProcessResult(0, 0, 'en-US', '')
        ],
        'flutter -d emulator-5554 drive example/test_driver/main.dart':
            <ProcessResult>[ProcessResult(0, 0, 'drive output', '')],
      };
      fakeProcessManager.fakeResults = processCalls;

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
          'id': 'Nexus_5X_API_27',
          'name': 'Nexus 5X',
          'category': 'mobile',
          'platformType': 'android'
        },
        {
          'id': 'Nexus_6P_API_28',
          'name': 'Nexus 6P',
          'category': 'mobile',
          'platformType': 'android'
        },
        {
          'id': 'Nexus_6_API_28',
          'name': 'Nexus 6',
          'category': 'mobile',
          'platformType': 'android'
        },
        {
          'id': 'Nexus_9_API_28',
          'name': 'Nexus 9',
          'category': 'mobile',
          'platformType': 'android'
        },
        {
          'id': 'Nexus_test_6P_API_30',
          'name': 'Nexus test 6P',
          'category': 'mobile',
          'platformType': 'android'
        },
        {
          'id': 'test',
          'name': null,
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
      devices:
        android:
          $emulatorName:
      frame: true
      ''';
      final result =
          await runScreenshots(configStr: configStr, client: mockDaemonClient);
      expect(result, isTrue);
//      fakeProcessManager.verifyCalls(processCalls.keys.toList());
    }, overrides: <Type, Generator>{ProcessManager: () => fakeProcessManager});
  });
}

class MockDaemonClient extends Mock implements DaemonClient {}
