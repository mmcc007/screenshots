import 'dart:convert';
//import 'dart:io';

import 'package:fake_process_manager/fake_process_manager.dart';
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
  const kRunningAndroidDeviceJson =
      '{"id":"emulator-5554","name":"Android SDK built for x86","platform":"android-x86","emulator":true,"category":"mobile","platformType":"android","ephemeral":true}';
  const kIPhoneUuid = '3b3455019e329e007e67239d9b897148244b5053';
  const kRunningRealIosDeviceJson =
      '{"id":"$kIPhoneUuid","name":"My iPhone","platform":"ios","emulator":false,"category":"mobile","platformType":"ios","ephemeral":true}';
  const kRunningRealAndroidDeviceJson =
      '{"id":"someandroiddeviceid","name":"My Android Phone","platform":"android","emulator":false,"category":"mobile","platformType":"android","ephemeral":true}';
  const kDevicesJson =
      '[$kRunningRealAndroidDeviceJson,$kRunningRealIosDeviceJson]';

  group('daemon client', () {
    const streamPeriod = 150;
    FakePlatform fakePlatform;

    setUp(() {
      fakePlatform = FakePlatform.fromPlatform(const LocalPlatform());
    });

    group('mocked process', () {
      MockProcessManager mockProcessManager;
      Process mockProcess;

      setUp(() async {
        mockProcessManager = MockProcessManager();
        mockProcess = MockProcess();

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
        expect(devices.length, 2);

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

    group('faked processes', () {
      FakeProcessManager fakeProcessManager;
      final List<String> stdinCaptured = <String>[];

      void _captureStdin(String item) {
        stdinCaptured.add(item);
      }

      setUp(() async {
        fakeProcessManager =
            FakeProcessManager(stdinResults: _captureStdin, isPeriodic: true);
      });

      testUsingContext('start simulator and get it\'s daemon device', () async {
        final daemonClient = DaemonClient();

        fakePlatform.operatingSystem = 'macos';

        // responses from daemon (called sequentially)
        List<int> getLine(int i) {
          final lines = <List<int>>[
            utf8.encode('Starting device daemon...\n'),
            utf8.encode(
                '[{"event":"daemon.connected","params":{"version":"0.0.0","pid":12345}}]\n'),
            utf8.encode('[{"id":0}]\n'),
            utf8.encode('[{"id":1,"result":$kDevicesJson}]\n'),
            utf8.encode('[{"id":2}]\n'),
          ];
          return lines[i];
        }

        final iosModel = 'iPhone 5c (GSM)';
        final iosPhoneName = 'My iPhone';
        fakeProcessManager.calls = [
          Call(
              'flutter daemon',
              ProcessResult(
                  0,
                  0,
                  Stream<List<int>>.periodic(
                      Duration(milliseconds: streamPeriod), getLine),
                  '')),
          Call(
              'sh -c ios-deploy -c || echo "no attached devices"',
              ProcessResult(
                  0,
                  0,
                  '[....] Waiting up to 5 seconds for iOS device to be connected\n[....] Found $kIPhoneUuid (N48AP, $iosModel, iphoneos, armv7s) a.k.a. \'$iosPhoneName\' connected through USB.',
                  '')),
        ];

        await daemonClient.start;

        final devices = await daemonClient.devices;
        expect(devices.length, 2);
        final iosRealDevice = devices[1];
        expect(iosRealDevice.iosModel, equals(iosModel));
        expect(iosRealDevice.name, equals(iosPhoneName));
        expect(iosRealDevice.id, equals(kIPhoneUuid));

        final exitCode = await daemonClient.stop;
        expect(exitCode, 0);

        fakeProcessManager.verifyCalls();
      }, skip: false, overrides: <Type, Generator>{
        ProcessManager: () => fakeProcessManager,
        Platform: () => fakePlatform,
//        Logger: () => VerboseLogger(StdoutLogger()),
      });
    });
  });

  group('marshall', () {
    test('daemon emulators', () {
      final List emulators = jsonDecode(kEmulatorsJson);
      final daemonEmulators = <DaemonEmulator>[];
      emulators.forEach((emulator) {
        daemonEmulators.add(loadDaemonEmulator(emulator));
      });
      expect(daemonEmulators.length, 7);
    });

    test('daemon devices', () {
      final List devices = jsonDecode(kDevicesJson);
      final daemonDevices = [];
      devices.forEach((device) {
        daemonDevices.add(loadDaemonDevice(device));
      });
      expect(daemonDevices.length, 2);
    });
  });
}

class MockProcess extends Mock implements Process {}

class MockProcessManager extends Mock implements ProcessManager {}

class MockStdIn extends Mock implements IOSink {}
