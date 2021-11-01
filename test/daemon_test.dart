import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart';
import 'package:screenshots/src/daemon_client.dart';
import 'package:screenshots/src/fastlane.dart' as fastlane;
import 'package:screenshots/src/globals.dart';
import 'package:screenshots/src/resources.dart' as resources;
import 'package:screenshots/src/run.dart';
import 'package:screenshots/src/screens.dart';
import 'package:screenshots/src/config.dart';
import 'package:screenshots/src/utils.dart' as utils;
import 'package:test/test.dart';

void main() {
  group('daemon test', () {
    test('start shipped daemon client', () async {
      final flutterHome = dirname(dirname((utils.cmd(['which', 'flutter']))));
      final flutterToolsHome = '$flutterHome/packages/flutter_tools';
//      print('flutterToolsHome=$flutterToolsHome');
      final daemonClient = await Process.start(
          'dart', <String>['tool/daemon_client.dart'],
          workingDirectory: flutterToolsHome);
//      print('shipped daemon client process started, pid: ${daemonClient.pid}');

      var connected = false;
      var waitingForResponse = false;
      daemonClient.stdout
          .transform<String>(utf8.decoder)
          .transform<String>(const LineSplitter())
          .listen((String line) async {
//        print('<<< $line');
        if (line.contains('daemon.connected')) {
//          print('connected');
          connected = true;
        }
        if (connected) {
          if (!waitingForResponse) {
            // send command
//            print('get emulators');
            daemonClient.stdin.writeln('emulators');
            waitingForResponse = true;
          } else {
            // get response
            if (line.contains('result')) {
//              print('emulators:$line');

              // shutdown daemon
//              print('shutdown');
              daemonClient.stdin.writeln('shutdown');
            }
          }
        }
      });
      daemonClient.stderr.listen((dynamic data) => stderr.add(data));

      // wait for exit code
//      print('exit code:${await daemonClient.exitCode}');
    }, skip:     true  );

    test('parse daemon result response', () {
      final expected =
          '[{"id":"Nexus_5X_API_27","name":"Nexus 5X"},{"id":"Nexus_6P_API_28","name":"Nexus 6P"},{"id":"Nexus_9_API_28","name":"Nexus 9"},{"id":"apple_ios_simulator","name":"iOS Simulator"}]';
      final response = '[{"id":0,"result":$expected}]';
      final respExp = RegExp(r'result":(.*)}\]');
      final match = respExp.firstMatch(response)?.group(1);
//      print('match=${jsonDecode(match)}');
      expect(match, expected);
    });

    test('parse daemon event response', () {
      final expected = [
        {
          'event': 'device.added',
          'params': {
            'id': 'emulator-5554',
            'name': 'Android SDK built for x86',
            'platform': 'android-x86',
            'emulator': true
          }
        }
      ];
      final eventType = 'device.added';
      final deviceId = 'emulator-5554';
      final params =
          '{"id":"$deviceId","name":"Android SDK built for x86","platform":"android-x86","emulator":true}';
      final response = '[{"event":"$eventType","params":$params}]';
      final responseInfo = jsonDecode(response);
      expect(responseInfo, expected);
      expect(responseInfo[0]['event'], eventType);
      expect(responseInfo[0]['params']['id'], deviceId);
    });

    test('start daemon client', () async {
      final daemonClient = DaemonClient();
      await daemonClient.start;
//      print('emulators: ${await daemonClient.emulators}');
//      print('devices: ${await daemonClient.devices}');
      final exitCode = await daemonClient.stop;
//      print('exit code: $exitCode');
      expect(exitCode, 0);
    }, skip:     true  );

    test('launch android emulator via daemon and shutdown', () async {
      final expected = 'emulator-5554';
      final emulatorId = 'Nexus_6P_API_28';
      final daemonClient = DaemonClient();
      await daemonClient.start;
      final deviceId = await daemonClient.launchEmulator(emulatorId);
      expect(deviceId, expected);
      await shutdownAndroidEmulator(daemonClient, deviceId);
    }, skip:     true  );

    test('parse ios-deploy response', () {
      final expectedDeviceId = '3b3455019e329e007e67239d9b897148244b5053';
      final expectedModel = 'iPhone 5c (GSM)';
      final regExp = RegExp(r'Found (\w+) \(\w+, (.*), \w+, \w+\)');
      final response =
          "[....] Found $expectedDeviceId (N48AP, $expectedModel, iphoneos, armv7s) a.k.a. 'Maurice’s iPhone' connected through USB.";

      final deviceId = regExp.firstMatch(response)?.group(1);
      final model = regExp.firstMatch(response)?.group(2);
//      print('deviceId=$deviceId');
//      print('model=$model');
      expect(deviceId, expectedDeviceId);
      expect(model, expectedModel);
    });

//    test('get ios model from device id', () {
//      final deviceId = '3b3455019e329e007e67239d9b897148244b5053';
//      final devices = getIosDevices();
//      print('devices=$devices');
//
//      final device = devices.firstWhere((device) => device['id'] == deviceId,
//          orElse: () => null);
//      device == null
//          ? print('device not attached')
//          : print('model=${device['model']}');
//    }, skip: utils.    true  );
//
//    test('run test on real device', () async {
//      final deviceName = 'iPhone 5c';
//      final testPath = 'test_driver/main.dart';
//      final daemonClient = DaemonClient();
//      await daemonClient.start;
//      final devices = await daemonClient.devices;
////      print('devices=$devices');
//      final device = devices.firstWhere(
//          (device) => device.iosModel.contains(deviceName),
//          orElse: () => null);
//      // clear existing screenshots from staging area
////    clearDirectory('$stagingDir/test');
//      // run the test
//      await utils.streamCmd(['flutter', '-d', device.id, 'drive', testPath],
//          workingDirectory: 'example');
//    }, timeout: Timeout(Duration(minutes: 2)), skip:     true  );
//
//    test('wait for start of android emulator', () async {
//      final id = 'Nexus_6P_API_28';
//      final daemonClient = DaemonClient();
////    daemonClient.verbose = true;
//      await daemonClient.start;
////    daemonClient.verbose;
//      final deviceId = await daemonClient.launchEmulator(id);
//
//      expect(utils.findAndroidDeviceId(id), deviceId);
//
//      // shutdown
//      await shutdownAndroidEmulator(daemonClient, deviceId);
//    }, skip:     true  );
//
//    test('join devices', () {
//      final configPath = 'test/screenshots_test.yaml';
//      final config = Config(configPath: configPath);
//      final androidInfo = config.androidDevices;
//      print('androidInfo=$androidInfo');
//      List deviceNames = config.deviceNames;
//      print('deviceNames=$deviceNames');
//    });

    test('run test on matching devices or emulators', () async {
      final configPath = 'test/screenshots_test.yaml';
      final screens = Screens();

      final config = Config(configPath: configPath);

      // init
      final stagingDir = config.stagingDir;
      await Directory(stagingDir + '/$kTestScreenshotsDir')
          .create(recursive: true);
      await resources.unpackScripts(stagingDir);
      await fastlane.clearFastlaneDirs(config, screens, RunMode.normal);

      final daemonClient = DaemonClient();
      await daemonClient.start;
      final devices = await daemonClient.devices;
      final emulators = await daemonClient.emulators;

      // for this test change directory
      final origDir = Directory.current;
      Directory.current = 'example';

      final screenshots = Screenshots(flavor: kNoFlavor);
      screenshots.devices = devices;
      screenshots.emulators = emulators;
      screenshots.config = config;
      screenshots.screens = screens;
      screenshots.runMode = RunMode.normal;
      await screenshots.runTestsOnAll();
      // allow other tests to continue
      Directory.current = origDir;
    }, timeout: Timeout(Duration(minutes: 4)), skip:     true  );
  });
}
