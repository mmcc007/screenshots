import 'dart:convert';

import 'package:fake_process_manager/fake_process_manager.dart';
import 'package:mockito/mockito.dart';
import 'package:platform/platform.dart';
import 'package:process/process.dart';
import 'package:screenshots/src/daemon_client.dart';
import 'package:test/test.dart';
import 'package:tool_base/tool_base.dart';

import 'src/context.dart';

main() {
  final String kEmulatorsJson = jsonEncode([
    {
      "id": "Nexus_6P_API_28",
      "name": "Nexus 6P",
      "category": "mobile",
      "platformType": "android"
    },
    {
      "id": "apple_ios_simulator",
      "name": "iOS Simulator",
      "category": "mobile",
      "platformType": "ios"
    }
  ]);
  final String kRunningAndroidEmulatorJson = jsonEncode({
    "id": "emulator-5554",
    "name": "Android SDK built for x86",
    "platform": "android-x86",
    "emulator": true,
    "category": "mobile",
    "platformType": "android",
    "ephemeral": true
  });
  const String kIPhoneUuid = '3b3455019e329e007e67239d9b897148244b5053';
  final String kRunningRealIosDeviceJson = jsonEncode({
    "id": "$kIPhoneUuid",
    "name": "My iPhone",
    "platform": "ios",
    "emulator": false,
    "category": "mobile",
    "platformType": "ios",
    "ephemeral": true
  });
  final String kRunningRealAndroidDeviceJson = jsonEncode({
    "id": "someandroiddeviceid",
    "name": "My Android Phone",
    "platform": "android",
    "emulator": false,
    "category": "mobile",
    "platformType": "android",
    "ephemeral": true
  });
  final String kRealDevicesJson = jsonEncode([
    jsonDecode(kRunningRealAndroidDeviceJson),
    jsonDecode(kRunningRealIosDeviceJson)
  ]);

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
            utf8.encode('[{"id":2,"result":$kRealDevicesJson}]\n'),
            utf8.encode('[{"id":3}]\n'),
            utf8.encode(
                '[{"event":"device.added","params":$kRunningAndroidEmulatorJson}]\n'),
            utf8.encode(
                '[{"event":"device.removed","params":$kRunningAndroidEmulatorJson}]\n'),
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
        expect(emulators.length, jsonDecode(kEmulatorsJson).length);

        final devices = await daemonClient.devices;
        expect(devices.length, jsonDecode(kRealDevicesJson).length);

        final deviceId = await daemonClient.launchEmulator('emulator id');
        expect(deviceId, 'emulator-5554');

        final expectedDeviceInfo = jsonDecode(kRunningAndroidEmulatorJson);
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

      testUsingContext('real devices (iPhone and Android)', () async {
        final daemonClient = DaemonClient();

        fakePlatform.operatingSystem = 'macos';

        // responses from daemon (called sequentially)
        List<int> getLine(int i) {
          final lines = <List<int>>[
            utf8.encode('Starting device daemon...\n'),
            utf8.encode(
                '[{"event":"daemon.connected","params":{"version":"0.0.0","pid":12345}}]\n'),
            utf8.encode('[{"id":0}]\n'),
            utf8.encode('[{"id":1,"result":$kRealDevicesJson}]\n'),
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
        final realAndroidDevice = devices[0];
        expect(realAndroidDevice.iosModel, isNull);
        expect(realAndroidDevice.name, equals('My Android Phone'));
        expect(realAndroidDevice.id, equals('someandroiddeviceid'));
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

    group('in CI', () {
      FakeProcessManager fakeProcessManager;
      FakePlatform fakePlatform;
      final List<String> stdinCaptured = <String>[];

      void _captureStdin(String item) {
        stdinCaptured.add(item);
      }

      setUp(() async {
        fakeProcessManager =
            FakeProcessManager(stdinResults: _captureStdin, isPeriodic: true);
        fakePlatform = FakePlatform.fromPlatform(const LocalPlatform());
      });

      testUsingContext('bad android emulator hack', () async {
        fakePlatform.environment = {
          'CI': 'true',
        };
        fakePlatform.operatingSystem = 'linux';
        final id = 'device id';
        final name = 'device name';
        final emulator = false;
        final emulatorId = null;
        final bogusRealAndroidDevice = [
          {
            "id": 1,
            "result": [
              {
                "id": id,
                "name": name,
                "platform": "android-arm",
                "emulator": emulator,
                "category": "mobile",
                "platformType": "android",
                "ephemeral": true,
                "emulatorId": emulatorId,
              }
            ]
          }
        ];
        final daemonClient = DaemonClient();

        // responses from daemon (called sequentially)
        List<int> getLine(int i) {
          final lines = <List<int>>[
            utf8.encode('Starting device daemon...\n'),
            utf8.encode('[${jsonEncode({
              "event": "daemon.connected",
              "params": {"version": "0.0.0", "pid": 12345}
            })}]\n'),
            utf8.encode('[{"id":0}]\n'),
            utf8.encode('[${jsonEncode(bogusRealAndroidDevice)}]\n'),
            utf8.encode('[{"id":2}]\n'),
          ];
          return lines[i];
        }

        fakeProcessManager.calls = [
          Call(
              'flutter daemon',
              ProcessResult(
                  0,
                  0,
                  Stream<List<int>>.periodic(
                      Duration(milliseconds: streamPeriod), getLine),
                  '')),
        ];

        await daemonClient.start;

        final devices = await daemonClient.devices;
        expect(devices.length, 1);
        final realAndroidDevice = devices[0];
        expect(realAndroidDevice.iosModel, isNull);
        expect(realAndroidDevice.name, equals(name));
        expect(realAndroidDevice.id, equals(id));
        expect(realAndroidDevice.emulator, isTrue);
        expect(realAndroidDevice.emulatorId, isNotNull);

        final exitCode = await daemonClient.stop;
        expect(exitCode, 0);

        fakeProcessManager.verifyCalls();
      }, overrides: <Type, Generator>{
        ProcessManager: () => fakeProcessManager,
        Platform: () => fakePlatform,
//        Logger: () => VerboseLogger(StdoutLogger()),
      });
    });
  });

  group('load', () {
    test('daemon emulators', () {
      final List emulators = jsonDecode(kEmulatorsJson);
      final daemonEmulators = <DaemonEmulator>[];
      emulators.forEach((emulator) {
        daemonEmulators.add(loadDaemonEmulator(emulator));
      });
      expect(daemonEmulators.length, emulators.length);
      expect(daemonEmulators[0].id, emulators[0]['id']);
    });

    test('daemon devices', () {
      final List devices = jsonDecode(kRealDevicesJson);
      final daemonDevices = <DaemonDevice>[];
      devices.forEach((device) {
        daemonDevices.add(loadDaemonDevice(device));
      });
      expect(daemonDevices.length, devices.length);
      expect(daemonDevices[0].id, devices[0]['id']);
    });
  });

  group('devices', (){
    test('equality', (){
      DaemonEmulator emulator1 = loadDaemonEmulator(jsonDecode(kEmulatorsJson)[0]);
      DaemonEmulator emulator2 = loadDaemonEmulator(jsonDecode(kEmulatorsJson)[0]);
      expect(emulator1, equals(emulator2));
      emulator2 = loadDaemonEmulator(jsonDecode(kEmulatorsJson)[1]);
      expect(emulator1, isNot(equals(emulator2)));

      DaemonDevice device1 = loadDaemonDevice(jsonDecode(kRealDevicesJson)[0]);
      DaemonDevice device2 = loadDaemonDevice(jsonDecode(kRealDevicesJson)[0]);
      expect(device1, equals(device2));
      device2 = loadDaemonDevice(jsonDecode(kRealDevicesJson)[1]);
      expect(device1, isNot(equals(device2)));

      expect(emulator1, isNot(equals(device1)));
    });
  });
}

class MockProcess extends Mock implements Process {}

class MockProcessManager extends Mock implements ProcessManager {}

class MockStdIn extends Mock implements IOSink {}
