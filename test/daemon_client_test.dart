import 'dart:convert';
import 'dart:io';

import 'package:mockito/mockito.dart';
import 'package:platform/platform.dart';
import 'package:process/process.dart';
import 'package:screenshots/src/base/context.dart';
import 'package:screenshots/src/daemon_client.dart';
import 'package:test/test.dart';

import 'src/context.dart';

main() {
  // responses from daemon (called sequentially)
  List<int> getLine(int i) {
    final lines = <List<int>>[
      utf8.encode('Starting device daemon...\n'),
      utf8.encode(
          '[{"event":"daemon.connected","params":{"version":"0.5.2","pid":47552}}]\n'),
      utf8.encode('[{"id":0}]\n'),
      utf8.encode(
          '[{"id":1,"result":[{"id":"Nexus_5X_API_27","name":"Nexus 5X","category":"mobile","platformType":"android"},{"id":"Nexus_6P_API_28","name":"Nexus 6P","category":"mobile","platformType":"android"},{"id":"Nexus_6_API_28","name":"Nexus 6","category":"mobile","platformType":"android"},{"id":"Nexus_9_API_28","name":"Nexus 9","category":"mobile","platformType":"android"},{"id":"Nexus_test_6P_API_30","name":"Nexus test 6P","category":"mobile","platformType":"android"},{"id":"test","name":null,"category":"mobile","platformType":"android"},{"id":"apple_ios_simulator","name":"iOS Simulator","category":"mobile","platformType":"ios"}]}]\n'),
      utf8.encode(
          '[{"id":2,"result":[{"id":"3b3455019e329e007e67239d9b897148244b5053","name":"Maurice’s iPhone","platform":"android","emulator":false,"category":"mobile","platformType":"android","ephemeral":true}]}]\n'),
      utf8.encode('[{"id":3}]\n'),
      utf8.encode(
          '[{"event":"device.added","params":{"id":"emulator-5554","name":"Android SDK built for x86","platform":"android-x86","emulator":true,"category":"mobile","platformType":"android","ephemeral":true}}]\n'),
      utf8.encode(
          '[{"event":"device.removed","params":{"id":"emulator-5554","name":"Android SDK built for x86","platform":"android-arm","emulator":false,"category":"mobile","platformType":"android","ephemeral":true}}]\n'),
      utf8.encode('[{"id":4}]\n'),
//        utf8.encode('bogus\n'),
    ];
    return lines[i];
  }

  group('daemon client', () {
    MockProcessManager mockProcessManager;
    Process mockProcess;
    FakePlatform fakePlatform;

    setUp(() async {
      mockProcessManager = MockProcessManager();
      mockProcess = MockProcess();
      fakePlatform = FakePlatform.fromPlatform(const LocalPlatform());

      when(mockProcessManager.start(any,
              environment: null, workingDirectory: null, runInShell: true))
          .thenAnswer((Invocation invocation) {
        final MockStdIn mockStdIn = MockStdIn();
        when(mockProcess.stdin).thenReturn(mockStdIn);

        when(mockProcess.stderr).thenAnswer(
            (Invocation invocation) => const Stream<List<int>>.empty());
        // Delay return of exitCode until after stdout stream data, since it terminates the logger.
        when(mockProcess.exitCode).thenAnswer((Invocation invocation) =>
            Future<int>.delayed(Duration.zero, () => 0));
        return Future<Process>.value(mockProcess);
      });
    });

    tearDown(() {});

    testUsingContext('start', () async {
      final daemonClient = DaemonClient();
      daemonClient.verbose = true;

      fakePlatform.operatingSystem = 'linux';
      when(mockProcess.stdout).thenAnswer((Invocation invocation) {
        return Stream<List<int>>.fromIterable(<List<int>>[
          utf8.encode('Starting device daemon...\n'),
          utf8.encode(
              '[{"event":"daemon.connected","params":{"version":"0.5.2","pid":47552}}]\n'),
          utf8.encode('[{"id":0}]\n'),
        ]);
      });

      await daemonClient.start;
    }, skip: true, overrides: <Type, Generator>{
      ProcessManager: () => mockProcessManager,
      Platform: () => fakePlatform
    });

    testUsingContext('get emulators and devices', () async {
      final daemonClient = DaemonClient();

      fakePlatform.operatingSystem = 'linux';
      when(mockProcess.stdout).thenAnswer((Invocation invocation) {
        return Stream<List<int>>.periodic(Duration(milliseconds: 120), getLine);
      });

      await daemonClient.start;

      final emulators = await daemonClient.emulators;
      expect(emulators.length, 7);

      final devices = await daemonClient.devices;
      expect(devices.length, 1);

      final deviceId = await daemonClient.launchEmulator('emulator id');
      expect(deviceId, 'emulator-5554');

      final expectedDeviceInfo = {
        'id': 'emulator-5554',
        'name': 'Android SDK built for x86',
        'platform': 'android-arm',
        'emulator': false,
        'category': 'mobile',
        'platformType': 'android',
        'ephemeral': true
      };
      final deviceInfo =
          await daemonClient.waitForEvent(EventType.deviceRemoved);
      expect(deviceInfo, expectedDeviceInfo);

      final exitCode = await daemonClient.stop;
      expect(exitCode, 0);
    }, skip: false, overrides: <Type, Generator>{
      ProcessManager: () => mockProcessManager,
      Platform: () => fakePlatform
    });
  });

  group('marshall', () {
    test('flutter emulators', () {
      final emulatorsJson = getLine(3);
      final List emulatorList = jsonDecode(utf8.decode(emulatorsJson));
//      print('emulatorMap=$emulatorList');
      emulatorList[0].values.forEach((emulators) {
//        print(emulators);
        if (emulators is List) {
          final flutterEmulators = [];
          for (var emulator in emulators) {
            DaemonEmulator flutterEmulator = loadDaemonEmulator(emulator);
            print('flutterDevice=$flutterEmulator');
            flutterEmulators.add(flutterEmulator);
          }
          expect(flutterEmulators.length, 7);
        }
      });
    });

    test('flutter devices', () {
      final devicesJson = getLine(4);
      final List devicesList = jsonDecode(utf8.decode(devicesJson));
      devicesList[0].values.forEach((devices) {
//        print(devices);
        if (devices is List) {
          final flutterDevices = [];
          for (var device in devices) {
            DaemonDevice flutterDevice = loadDaemonDevice(device);
            print('flutterDevice=$flutterDevice');
            flutterDevices.add(flutterDevice);
          }
          expect(flutterDevices.length, 1);
        }
      });
    });
  });
}

class MockProcess extends Mock implements Process {}

class MockProcessManager extends Mock implements ProcessManager {}

class MockStdIn extends Mock implements IOSink {}
