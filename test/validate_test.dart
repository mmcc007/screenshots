import 'package:fake_process_manager/fake_process_manager.dart';
import 'package:process/process.dart';
import 'package:screenshots/src/config.dart';
import 'package:screenshots/src/daemon_client.dart';
import 'package:screenshots/src/screens.dart';
import 'package:screenshots/src/utils.dart';
import 'package:screenshots/src/validate.dart';
import 'package:test/test.dart';
import 'package:tool_base/tool_base.dart' hide Config;
import 'src/context.dart';

main() {
  group('validate', () {
    FakeProcessManager fakeProcessManager;

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

    setUp(() {
      fakeProcessManager = FakeProcessManager();
    });

    testUsingContext('pass with \'availability\'', () async {
      final configStr = '''
          tests:
            - example/test_driver/main.dart
          staging: /tmp/screenshots
          locales:
            - en-US
            - fr-CA
          devices:
            android:
              Nexus 6P:
                orientation: LandscapeRight
            ios:
              iPhone X:
                orientation: LandscapeRight
          frame: true
      ''';
      final config = Config(configStr: configStr);
      final screens = Screens();
      await screens.init();
      final emulator = {
        "id": "Nexus_6P_API_28",
        "name": "Nexus 6P",
        "category": "mobile",
        "platformType": "android"
      };
      final allEmulators = <DaemonEmulator>[loadDaemonEmulator(emulator)];
      final allDevices = <DaemonDevice>[];

      fakeProcessManager.calls = [callListIosDevices];

      final isValid =
          await isValidConfig(config, screens, allDevices, allEmulators);
      expect(isValid, isTrue);
    }, skip: false, overrides: <Type, Generator>{
      ProcessManager: () => fakeProcessManager,
//      Logger: () => VerboseLogger(StdoutLogger()),
      Platform: () => FakePlatform.fromPlatform(const LocalPlatform())
        ..operatingSystem = 'macos',
    });

    testUsingContext('pass with \'isAvailable\'', () async {
      final callListIosDevices = Call(
          'xcrun simctl list devices --json',
          ProcessResult(
              0,
              0,
              '''
                {
                  "devices" : {
                    "com.apple.CoreSimulator.SimRuntime.iOS-13-2" : [
                      {
                        "state" : "Shutdown",
                        "isAvailable" : true,
                        "name" : "iPhone X",
                        "udid" : "FAD89341-9B18-4A40-92F5-0440F1B19731"
                      },
                      {
                        "state" : "Shutdown",
                        "isAvailable" : true,
                        "name" : "iPad Pro (12.9-inch) (3rd generation)",
                        "udid" : "A225B800-9979-48C4-BF28-922984806788"
                      }
                    ]
                  }
                }
                ''',
              ''));
      final configStr = '''
          tests:
            - example/test_driver/main.dart
          staging: /tmp/screenshots
          locales:
            - en-US
            - fr-CA
          devices:
            android:
              Nexus 6P:
                orientation: LandscapeRight
            ios:
              iPhone X:
                orientation: LandscapeRight
          frame: true
      ''';
      final config = Config(configStr: configStr);
      final screens = Screens();
      await screens.init();
      final emulator = {
        "id": "Nexus_6P_API_28",
        "name": "Nexus 6P",
        "category": "mobile",
        "platformType": "android"
      };
      final allEmulators = <DaemonEmulator>[loadDaemonEmulator(emulator)];
      final allDevices = <DaemonDevice>[];

      fakeProcessManager.calls = [callListIosDevices];

      final isValid =
      await isValidConfig(config, screens, allDevices, allEmulators);
      expect(isValid, isTrue);
      fakeProcessManager.verifyCalls();
    }, skip: false, overrides: <Type, Generator>{
      ProcessManager: () => fakeProcessManager,
//      Logger: () => VerboseLogger(StdoutLogger()),
      Platform: () => FakePlatform.fromPlatform(const LocalPlatform())
        ..operatingSystem = 'macos',
    });

    testUsingContext('getIosSimulators', () async {
      final callListIosDevices = Call(
          'xcrun simctl list devices --json',
          ProcessResult(
              0,
              0,
              '''
                {
                  "devices" : {
                    "com.apple.CoreSimulator.SimRuntime.iOS-13-2" : [
                      {
                        "state" : "Shutdown",
                        "isAvailable" : true,
                        "name" : "iPhone 11 Pro Max",
                        "udid" : "FAD89341-9B18-4A40-92F5-0440F1B19731"
                      },
                      {
                        "state" : "Shutdown",
                        "isAvailable" : true,
                        "name" : "iPad Pro (12.9-inch) (3rd generation)",
                        "udid" : "A225B800-9979-48C4-BF28-922984806788"
                      }
                    ]
                  }
                }
                ''',
              ''));

      fakeProcessManager.calls = [callListIosDevices];

      final Map simulators = getIosSimulators();
      final isSimulatorFound= isSimulatorInstalled(simulators, 'iPhone 11 Pro Max');
      expect(isSimulatorFound, isTrue);
    }, skip: false, overrides: <Type, Generator>{
      ProcessManager: () => fakeProcessManager,
//      Logger: () => VerboseLogger(StdoutLogger()),
    });

    testUsingContext('fail', () async {
      final BufferLogger logger = context.get<Logger>();
      final configStr = '''
          tests:
            - example/test_driver/main.dartx
          staging: /tmp/screenshots
          locales:
            - en-US
            - fr-CA
          devices:
            android:
              Bad android phone:
              Unknown android phone:
                frame: false
              Nexus 6P:
                orientation: LandscapeRight
            ios:
              Bad ios phone:
              iPhone X:
                orientation: LandscapeRight
          frame: true
      ''';
      final config = Config(configStr: configStr);
      final screens = Screens();
      await screens.init();
      final emulator = {
        "id": "ANY_EMULATOR_ID",
        "name": "Nexus 6P",
        "category": "mobile",
        "platformType": "android"
      };
      final allEmulators = <DaemonEmulator>[loadDaemonEmulator(emulator)];
      final allDevices = <DaemonDevice>[];

      fakeProcessManager.calls = [callListIosDevices, callListIosDevices];

      final isValid =
          await isValidConfig(config, screens, allDevices, allEmulators);
      expect(isValid, isFalse);
      expect(logger.statusText, contains('Guide'));
      expect(logger.statusText, contains('Use a device with a supported screen'));
      expect(logger.errorText, contains('File \'example/test_driver/main.dartx\' not found.'));
      expect(logger.errorText, contains('Invalid config: \'example/test_driver/main.dartx\' in screenshots.yaml'));
      expect(logger.errorText, contains('Screen not available for device \'Bad android phone\' in screenshots.yaml.'));
      expect(logger.errorText, contains('Screen not available for device \'Bad ios phone\' in screenshots.yaml.'));
      expect(logger.errorText, contains('No device attached or emulator installed for device \'Bad android phone\' in screenshots.yaml.'));
      expect(logger.errorText, contains('No device attached or emulator installed for device \'Unknown android phone\' in screenshots.yaml.'));
      expect(logger.errorText, contains('No device attached or simulator installed for device \'Bad ios phone\' in screenshots.yaml.'));
    }, skip: false, overrides: <Type, Generator>{
      ProcessManager: () => fakeProcessManager,
      Logger: () => BufferLogger(),
    });

    testUsingContext('show guide', () async {
      final BufferLogger logger = context.get<Logger>();
      final screens = Screens();
      await screens.init();
      final installedEmulator = loadDaemonEmulator({
        "id": "Nexus_6P_API_28",
        "name": "Nexus 6P",
        "category": "mobile",
        "platformType": "android"
      });
      final allEmulators = <DaemonEmulator>[installedEmulator];
      final startedEmulator = loadDaemonDevice({
        "id": "emulator-5554",
        "name": "Android SDK built for x86",
        "platform": "android-x86",
        "emulator": true,
        "category": "mobile",
        "platformType": "android",
        "ephemeral": true
      });
      final realIosDevice = loadDaemonDevice({
        "id": "3b3455019e329e007e67239d9b897148244b5053",
        "name": "My iPhone",
        "platform": "ios",
        "emulator": false,
        "category": "mobile",
        "platformType": "ios",
        "ephemeral": true,
        'model': 'iPhone model'
      });
      final realAndroidDevice = loadDaemonDevice({
        "id": "device id",
        "name": "Adroid Phone Name",
        "platform": "android",
        "emulator": false,
        "category": "mobile",
        "platformType": "android",
        "ephemeral": true
      });
      final allDevices = <DaemonDevice>[
        startedEmulator,
        realIosDevice,
        realAndroidDevice,
      ];
      expect(
          () async => await generateConfigGuide(
              screens, allDevices, allEmulators, 'myScreenshots.yaml'),
          returnsNormally);
      expect(logger.statusText, contains('Guide'));
      expect(logger.statusText, contains(realIosDevice.iosModel));
      expect(logger.statusText, contains(realAndroidDevice.name));
      expect(logger.statusText, isNot(contains(startedEmulator.id)));
      expect(logger.statusText, contains(installedEmulator.name));
      expect(logger.errorText, '');

    }, skip: false, overrides: <Type, Generator>{
      Logger: () => BufferLogger(),
    });
  });
}
