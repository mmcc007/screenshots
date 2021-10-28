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

void main() {
  group('validate', () {
    var fakeProcessManager = FakeProcessManager();
    var macos = FakePlatform(
      stdoutSupportsAnsi: false,
      operatingSystem: 'macos',
      environment: {'CI': 'false'},
    );

    setUp(() {
      fakeProcessManager = FakeProcessManager();
    });

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

    testUsingContext('pass on iOS with \'availability\'', () async {
      final configStr = '''
          tests:
            - example/test_driver/main.dart
          staging: /tmp/screenshots
          locales:
            - en-US
            - fr-CA
          devices:
            ios:
              iPhone X:
          frame: true
      ''';
      final config = Config(configStr: configStr);
      final screens = Screens();
      final allEmulators = <DaemonEmulator>[];
      final allDevices = <DaemonDevice>[];

      fakeProcessManager.calls = [callListIosDevices];

      final isValid =
          await isValidConfig(config, screens, allDevices, allEmulators);
      expect(isValid, isTrue);
    }, skip: false, overrides: <Type, Generator>{
      ProcessManager: () => fakeProcessManager,
//      Logger: () => VerboseLogger(StdoutLogger()),
      Platform: () => macos
    });

    testUsingContext('pass on iOS with \'isAvailable\'', () async {
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
            ios:
              iPhone X:
          frame: true
      ''';
      final config = Config(configStr: configStr);
      final screens = Screens();
      final allEmulators = <DaemonEmulator>[];
      final allDevices = <DaemonDevice>[];

      fakeProcessManager.calls = [callListIosDevices];

      final isValid =
      await isValidConfig(config, screens, allDevices, allEmulators);
      expect(isValid, isTrue);
      fakeProcessManager.verifyCalls();
    }, skip: false, overrides: <Type, Generator>{
      ProcessManager: () => fakeProcessManager,
//      Logger: () => VerboseLogger(StdoutLogger()),
      Platform: () => macos,
    });

    testUsingContext('getIosSimulators', () async {
      fakeProcessManager.calls = [callListIosDevices];
      final simulators = getIosSimulators();
      final isSimulatorFound= isSimulatorInstalled(simulators, 'iPhone X');
      expect(isSimulatorFound, isTrue);
      fakeProcessManager.verifyCalls();
   }, skip: false, overrides: <Type, Generator>{
      ProcessManager: () => fakeProcessManager,
//      Logger: () => VerboseLogger(StdoutLogger()),
    });

    testUsingContext('fail', () async {
      final logger = context.get<Logger>()! as BufferLogger;
      final configStr = '''
          tests:
            - example/test_driver/main.dartx
          staging: /tmp/screenshots
          locales:
            - en-US
            - fr-CA
          devices:
            android:
              Android Device (with no screen):
              Unknown android phone:
                frame: false
              Nexus 6P:
                orientation: LandscapeRight
            ios:
              iOS Device (with no screen):
              iPhone X:
                orientation: LandscapeRight
          frame: true
      ''';
      final config = Config(configStr: configStr);
      final screens = Screens();
      final emulator = loadDaemonEmulator({
        "id": "NEXUS_6P_API_28",
        "name": "NEXUS 6P API 28",
        "category": "mobile",
        "platformType": "android"
      })!;
      final device = loadDaemonDevice({
        "id": "emulator-5554",
        "name": "Android SDK built for x86 64",
        "platform": "android-arm",
        "emulator": true,
        "category": "mobile",
        "platformType": "android",
        "ephemeral": true,
        "emulatorId": 'NEXUS_6P_API_28'
      });
      final allEmulators = <DaemonEmulator>[emulator];
      final allDevices = <DaemonDevice>[device];

      fakeProcessManager.calls = [callListIosDevices, callListIosDevices];

      var isValid =
          await isValidConfig(config, screens, allDevices, allEmulators);
//      print(logger.statusText);
//      print(logger.errorText);
      expect(isValid, isFalse);
      expect(logger.statusText, contains('Screen Guide'));
      expect(logger.statusText, contains('Device Guide'));
      expect(logger.statusText, contains('Attached devices'));
      expect(logger.statusText, contains('Installed emulators'));
      expect(logger.statusText, contains('Installed simulators'));

      expect(logger.errorText, contains('File \'example/test_driver/main.dartx\' not found.'));
      expect(logger.errorText, contains('No device attached or emulator installed for device \'Unknown android phone\''));
      expect(logger.errorText, contains('Screen not available for device \'Android Device (with no screen)\''));
      expect(logger.errorText, contains('Screen not available for device \'iOS Device (with no screen)\''));
      expect(logger.errorText, contains('No device attached or emulator installed for device \'Unknown android phone\''));
      expect(logger.errorText, isNot(contains('No device attached or simulator installed for device \'Bad ios phone\'')));
      fakeProcessManager.verifyCalls();

//       fakePlatform.operatingSystem = 'linux';
//       isValid =
//      await isValidConfig(config, screens, allDevices, allEmulators);
//      expect(isValid, isFalse);
//      expect(logger.statusText, contains('Guide'));
//      expect(logger.statusText, contains('Use a device with a supported screen'));
//      expect(logger.errorText, contains('File \'example/test_driver/main.dartx\' not found.'));
//      expect(logger.errorText, contains('Invalid config: \'example/test_driver/main.dartx\' in screenshots.yaml'));
//      expect(logger.errorText, contains('Screen not available for device \'Bad android phone\' in screenshots.yaml.'));
//      expect(logger.errorText, isNot(contains('Screen not available for device \'Bad ios phone\' in screenshots.yaml.')));
//      expect(logger.errorText, contains('No device attached or emulator installed for device \'Bad android phone\' in screenshots.yaml.'));
//      expect(logger.errorText, contains('No device attached or emulator installed for device \'Unknown android phone\' in screenshots.yaml.'));
//      expect(logger.errorText, isNot(contains('No device attached or simulator installed for device \'Bad ios phone\' in screenshots.yaml.')));
    }, skip: false, overrides: <Type, Generator>{
      Logger: () => BufferLogger(),
      Platform: () => macos,
      ProcessManager: () => fakeProcessManager,
    });

    testUsingContext('show device guide', () async {
      final logger = context.get<Logger>()! as BufferLogger;
      final screens = Screens();
      final installedEmulator = loadDaemonEmulator({
        "id": "Nexus_6P_API_28",
        "name": "Android SDK built for x86",
        "category": "mobile",
        "platformType": "android"
      })!;
      final allEmulators = <DaemonEmulator>[installedEmulator];
      final runningEmulator = loadDaemonDevice({
        "id": "emulator-5554",
        "name": "Android SDK built for x86",
        "platform": "android-x86",
        "emulator": true,
        "category": "mobile",
        "platformType": "android",
        "ephemeral": true,
        "emulatorId": "NEXUS_6P_API_28",
      });
      final realIosDevice = loadDaemonDevice({
        "id": "3b3455019e329e007e67239d9b897148244b5053",
        "name": "My iPhone",
        "platform": "ios",
        "emulator": false,
        "category": "mobile",
        "platformType": "ios",
        "ephemeral": true,
        'model': 'Real iPhone'
      });
      final realAndroidDevice = loadDaemonDevice({
        "id": "1080308019003347",
        "name": "Real Android Phone",
        "platform": "android",
        "emulator": false,
        "category": "mobile",
        "platformType": "android",
        "ephemeral": true
      });
      final allDevices = <DaemonDevice>[
        runningEmulator,
        realIosDevice,
        realAndroidDevice,
      ];
      fakeProcessManager.calls = [callListIosDevices];
      expect(
          () async => deviceGuide(
              screens, allDevices, allEmulators, 'myScreenshots.yaml'),
          returnsNormally);
      expect(logger.statusText, contains('Device Guide'));
      expect(logger.statusText, isNot(contains('Screen Guide')));
      expect(logger.statusText, contains(realIosDevice.iosModel));
      expect(logger.statusText, contains(realAndroidDevice.name));
      expect(logger.statusText, contains(runningEmulator.id));
      expect(logger.statusText, contains(installedEmulator.id));
      expect(logger.errorText, '');
//      print(logger.statusText);
//      print(logger.errorText);
      fakeProcessManager.verifyCalls();
    }, skip: false, overrides: <Type, Generator>{
      Logger: () => BufferLogger(),
      Platform: () => macos,
      ProcessManager: () => fakeProcessManager,
    });
  });
}
