import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart';
import 'package:screenshots/daemon_client.dart';
import 'package:screenshots/screenshots.dart';
import 'package:screenshots/utils.dart';
import 'package:test/test.dart';

main() {
  test('start shipped daemon client', () async {
    final flutterHome =
        dirname(dirname((cmd('which', ['flutter'], '.', true))));
    final flutterToolsHome = '$flutterHome/packages/flutter_tools';
    print('flutterToolsHome=$flutterToolsHome');
    final daemonClient = await Process.start(
        'dart', <String>['tool/daemon_client.dart'],
        workingDirectory: flutterToolsHome);
    print('shipped daemon client process started, pid: ${daemonClient.pid}');

    bool connected = false;
    bool waitingForResponse = false;
    daemonClient.stdout
        .transform<String>(utf8.decoder)
        .transform<String>(const LineSplitter())
        .listen((String line) async {
      print('<<< $line');
      if (line.contains('daemon.connected')) {
        print('connected');
        connected = true;
      }
      if (connected) {
        if (!waitingForResponse) {
          // send command
          print('get emulators');
          daemonClient.stdin.writeln('emulators');
          waitingForResponse = true;
        } else {
          // get response
          if (line.contains('result')) {
            print('emulators:$line');

            // shutdown daemon
            print('shutdown');
            daemonClient.stdin.writeln('shutdown');
          }
        }
      }
    });
    daemonClient.stderr.listen((dynamic data) => stderr.add(data));

    // wait for exit code
    print('exit code:${await daemonClient.exitCode}');
  });

  test('parse daemon response', () {
    final expected =
        '[{"id":"Nexus_5X_API_27","name":"Nexus 5X"},{"id":"Nexus_6P_API_28","name":"Nexus 6P"},{"id":"Nexus_9_API_28","name":"Nexus 9"},{"id":"apple_ios_simulator","name":"iOS Simulator"}]';
    final response = '[{"id":0,"result":$expected}]';
    final respExp = RegExp(r'result":(.*)}\]');
    final match = respExp.firstMatch(response).group(1);
    print('match=${jsonDecode(match)}');
    expect(match, expected);
  });

  test('start daemon client', () async {
    await daemonClient.start;
    print('emulators: ${await daemonClient.emulators}');
    print('devices: ${await daemonClient.devices}');
    final exitCode = await daemonClient.stop;
    print('exit code: $exitCode');
    expect(exitCode, 0);
  });

  test('launch android emulator via daemon', () async {
    final emulatorId = 'Nexus_6P_API_28';
    final name = 'Nexus 6P';
    final deviceId = 'emulator-5554';
    await daemonClient.start;
    print('starting $emulatorId...');
    daemonClient.verbose = true;
    await daemonClient.launchEmulator(emulatorId);
    daemonClient.verbose = false;
    print('$emulatorId started up');
    expect(findAndroidDeviceId(emulatorId), deviceId);
    print('emulator startup confirmed');

    // shutdown
    await shutdownAndroidEmulator(deviceId, name);
  });

  test('wait for android emulator to shutdown', () async {
    final deviceId = 'emulator-5554';
    final deviceName = 'my device';
    await waitAndroidEmulatorShutdown(deviceId, deviceName);
  });

  test('launch ios simulator', () async {
    final emulatorId = 'apple_ios_simulator';
//    daemonClient.verbose = true;
    await daemonClient.start;
    await daemonClient.launchEmulator(emulatorId);

    // shutdown
  });

  test('parse ios-deploy response', () {
    final expectedDeviceId = '3b3455019e329e007e67239d9b897148244b5053';
    final expectedModel = 'iPhone 5c (GSM)';
    final regExp = RegExp(r'Found (\w+) \(\w+, (.*), \w+, \w+\)');
    final response =
        "[....] Found $expectedDeviceId (N48AP, $expectedModel, iphoneos, armv7s) a.k.a. 'Maurice’s iPhone' connected through USB.";

    final deviceId = regExp.firstMatch(response).group(1);
    final model = regExp.firstMatch(response).group(2);
    print('deviceId=$deviceId');
    print('model=$model');
    expect(deviceId, expectedDeviceId);
    expect(model, expectedModel);
  });

  test('get ios model from device id', () {
    final deviceId = '3b3455019e329e007e67239d9b897148244b5053';
    final devices = iosDevices();
    print('devices=$devices');

    final device = devices.firstWhere(
        (device) => device['deviceId'] == deviceId,
        orElse: () => null);
    print('model=${device['model']}');
  });

  test('run test on real device', () async {
    final deviceName = 'iPhone 5c';
    final testPath = 'test_driver/main.dart';
    await daemonClient.start;
    final devices = await daemonClient.devices;
    print('devices=$devices');
    final device = devices.firstWhere(
        (device) => device['model'].contains(deviceName),
        orElse: () => null);
    // clear existing screenshots from staging area
//    clearDirectory('$stagingDir/test');
    // run the test
    await streamCmd(
        'flutter', ['-d', device['id'], 'drive', testPath], 'example');
  }, timeout: Timeout(Duration(minutes: 2)));

  test('wait for start of android emulator', () async {
    final id = 'Nexus_6P_API_28';
    final name = 'Nexus 6P';
    final deviceId = 'emulator-5554';
    daemonClient.verbose = true;
    await daemonClient.start;
    daemonClient.verbose;
    await daemonClient.launchEmulator(id);

    expect(findAndroidDeviceId(id), deviceId);

    // shutdown
    await shutdownAndroidEmulator(deviceId, name);
  });

  test('run test on matching device or emulator', () async {
    final realDevice = 'iPhone 5c'; // device
    final androidEmulator = 'Nexus 6P'; // android emulator
    final iosSimulator = 'iPhone 7'; // ios simulator
    final deviceNames = [realDevice, androidEmulator, iosSimulator];
    final testPath = 'test_driver/main.dart';

    await daemonClient.start;

    for (final deviceName in deviceNames) {
      // look for matching device first
      final devices = await daemonClient.devices;
      final emulators = await daemonClient.emulators;
      print('devices=$devices');
      print('emulators=$emulators');
      final device = devices.firstWhere((device) {
        if (device['platform'] == 'ios') {
          // ios device or simulator
          if (device['emulator']) {
            return device['name'] == deviceName;
          } else {
            return device['model'].contains(deviceName);
          }
        } else {
          // android device or emulator
          if (device['emulator']) {
            return findDeviceEmulator(emulators, device['id'])['name'] ==
                deviceName;
          } else {
            return device['name'] == deviceName;
          }
        }
      }, orElse: () => null);

      String deviceId;
      Map emulator = null;
      Map simulatorInfo = null;
      if (device != null) {
        deviceId = device['id'];
      } else {
        // if no matching device, look for matching android emulator
        emulator = findEmulator(emulators, deviceName);
        if (emulator != null) {
          final emulatorId = emulator['id'];
          await daemonClient.launchEmulator(emulatorId);
          deviceId = findAndroidDeviceId(emulatorId);
        } else {
          // if no matching android emulator, look for matching ios simulator
          simulatorInfo = getHighestIosDevice(getIosDevices(), deviceName);
          deviceId = simulatorInfo['udid'];
          cmd('xcrun', ['simctl', 'boot', deviceId]);
        }
      }

      // run test
      print('Running test on $deviceName...');
      await streamCmd(
          'flutter', ['-d', deviceId, 'drive', testPath], 'example');

      // if an emulator was started, shut it down
      if (emulator != null) {
        await shutdownAndroidEmulator(deviceId, emulator['name']);
      }
      if (simulatorInfo != null) {
        cmd('xcrun', ['simctl', 'shutdown', deviceId]);
      }
    }
  }, timeout: Timeout(Duration(minutes: 4)));

  test('firstwhere', () {
    final expected = {'id': 2};
    final listOfMap = [
      {'id': 1},
      expected,
      {'id': 3}
    ];
    final findIt = (List list, int id) =>
        list.firstWhere((map) => map['id'] == id, orElse: () => null);

    // found
    expect(findIt(listOfMap, expected['id']), expected);
    // not found
    expect(findIt(listOfMap, 4), null);
  });
}

Map findEmulator(List emulators, String emulatorName) {
  return emulators.firstWhere((emulator) => emulator['name'] == emulatorName,
      orElse: () => null);
}

Map findDeviceEmulator(List emulators, String deviceId) {
  return emulators.firstWhere(
      (emulator) => emulator['id'] == getAndroidEmulatorId(deviceId),
      orElse: () => null);
}
