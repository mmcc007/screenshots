import 'dart:convert';
import 'dart:io';

import 'package:mockito/mockito.dart';
import 'package:platform/platform.dart';
import 'package:process/process.dart';
import 'package:screenshots/src/daemon_client.dart';
import 'package:test/test.dart';
import 'package:tool_base/tool_base.dart';

import 'src/context.dart';

main() {
  const kEmulatorsJson =
      '[{"id":"Nexus_5X_API_27","name":"Nexus 5X","category":"mobile","platformType":"android"},{"id":"Nexus_6P_API_28","name":"Nexus 6P","category":"mobile","platformType":"android"},{"id":"Nexus_6_API_28","name":"Nexus 6","category":"mobile","platformType":"android"},{"id":"Nexus_9_API_28","name":"Nexus 9","category":"mobile","platformType":"android"},{"id":"Nexus_test_6P_API_30","name":"Nexus test 6P","category":"mobile","platformType":"android"},{"id":"test","name":null,"category":"mobile","platformType":"android"},{"id":"apple_ios_simulator","name":"iOS Simulator","category":"mobile","platformType":"ios"}]';
  const kDevicesJson =
      '[{"id":"3b3455019e329e007e67239d9b897148244b5053","name":"Maurice’s iPhone","platform":"android","emulator":false,"category":"mobile","platformType":"android","ephemeral":true}]';
  const kRunningAndroidDeviceJson =
      '{"id":"emulator-5554","name":"Android SDK built for x86","platform":"android-x86","emulator":true,"category":"mobile","platformType":"android","ephemeral":true}';

  group('daemon client', () {
    const streamPeriod = 150;
    MockProcessManager mockProcessManager;
    Process mockProcess;
    FakePlatform fakePlatform;

    setUp(() async {
      mockProcessManager = MockProcessManager();
      mockProcess = MockProcess();
      fakePlatform = FakePlatform.fromPlatform(const LocalPlatform());

      when(mockProcessManager.start(any)).thenAnswer((Invocation invocation) {
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

    testUsingContext('start/stop', () async {
      DaemonClient daemonClient = DaemonClient();

      fakePlatform.operatingSystem = 'linux';
      List<int> getLine(int i) {
        final lines = <List<int>>[
          utf8.encode('Starting device daemon...\n'),
          utf8.encode(
              '[{"event":"daemon.connected","params":{"version":"1.2.3","pid":12345}}]\n'),
          utf8.encode('[{"id":0}]\n'),
          utf8.encode('[{"id":1}]\n'),
        ];
        return lines[i];
      }

      when(mockProcess.stdout).thenAnswer((_) {
        return Stream<List<int>>.periodic(
            Duration(milliseconds: streamPeriod), getLine);
      });

      await daemonClient.start;
      await daemonClient.stop;

      verify(mockProcessManager.start(any)).called(1);
      verify(mockProcess.stdin).called(2);
      verify(mockProcess.stdout).called(1);
      verify(mockProcess.stderr).called(1);
      verify(mockProcess.exitCode).called(1);
    }, skip: false, overrides: <Type, Generator>{
      ProcessManager: () => mockProcessManager,
      Platform: () => fakePlatform,
//      Logger: () => VerboseLogger(StdoutLogger()),
    });

    testUsingContext('get emulators and devices, and launch emulator',
        () async {
      final daemonClient = DaemonClient();

      fakePlatform.operatingSystem = 'linux';

      // responses from daemon (called sequentially)
      List<int> getLine(int i) {
        final lines = <List<int>>[
          utf8.encode('Starting device daemon...\n'),
          utf8.encode(
              '[{"event":"daemon.connected","params":{"version":"0.0.0","pid":12345}}]\n'),
          utf8.encode('[{"id":0}]\n'),
          utf8.encode('[{"id":1,"result":$kEmulatorsJson}]\n'),
          utf8.encode('[{"id":2,"result":$kDevicesJson}]\n'),
          utf8.encode('[{"id":3}]\n'),
          utf8.encode(
              '[{"event":"device.added","params":$kRunningAndroidDeviceJson}]\n'),
          utf8.encode(
              '[{"event":"device.removed","params":$kRunningAndroidDeviceJson}]\n'),
          utf8.encode('[{"id":4}]\n'),
        ];
        return lines[i];
      }

      when(mockProcess.stdout).thenAnswer((_) {
        return Stream<List<int>>.periodic(
            Duration(milliseconds: streamPeriod), getLine);
      });

      await daemonClient.start;

      final emulators = await daemonClient.emulators;
      expect(emulators.length, 7);

      final devices = await daemonClient.devices;
      expect(devices.length, 1);

      final deviceId = await daemonClient.launchEmulator('emulator id');
      expect(deviceId, 'emulator-5554');

      final expectedDeviceInfo = jsonDecode(kRunningAndroidDeviceJson);
      final deviceInfo =
          await daemonClient.waitForEvent(EventType.deviceRemoved);
      expect(deviceInfo, expectedDeviceInfo);

      final exitCode = await daemonClient.stop;
      expect(exitCode, 0);

      verify(mockProcessManager.start(any)).called(1);
      verify(mockProcess.stdin).called(5);
      verify(mockProcess.stdout).called(1);
      verify(mockProcess.stderr).called(1);
      verify(mockProcess.exitCode).called(1);
    }, skip: false, overrides: <Type, Generator>{
      ProcessManager: () => mockProcessManager,
      Platform: () => fakePlatform,
//      Logger: () => VerboseLogger(StdoutLogger()),
    });
  });

  group('marshall', () {
    test('daemon emulators', () {
      final List emulatorList = jsonDecode(kEmulatorsJson);
      emulatorList.forEach((emulators) {
        if (emulators is List) {
          final flutterEmulators = [];
          for (var emulator in emulators) {
            DaemonEmulator flutterEmulator = loadDaemonEmulator(emulator);
//            print('flutterDevice=$flutterEmulator');
            flutterEmulators.add(flutterEmulator);
          }
          expect(flutterEmulators.length, 7);
        }
      });
    });

    test('daemon devices', () {
      final List devicesList = jsonDecode(kDevicesJson);
      devicesList.forEach((devices) {
        if (devices is List) {
          final flutterDevices = [];
          for (var device in devices) {
            DaemonDevice flutterDevice = loadDaemonDevice(device);
//            print('flutterDevice=$flutterDevice');
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
