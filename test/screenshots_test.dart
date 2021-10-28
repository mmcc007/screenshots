import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:process/process.dart';
import 'package:screenshots/src/config.dart';
import 'package:screenshots/src/context_runner.dart';
import 'package:screenshots/src/daemon_client.dart';
import 'package:screenshots/src/fastlane.dart';
import 'package:screenshots/src/globals.dart';
import 'package:screenshots/src/image_magick.dart';
import 'package:screenshots/src/image_processor.dart';
import 'package:screenshots/src/orientation.dart' as orient;
import 'package:screenshots/src/orientation.dart';
import 'package:screenshots/src/resources.dart' as resources;
import 'package:screenshots/src/run.dart';
import 'package:screenshots/src/run.dart' as run;
import 'package:screenshots/src/screens.dart';
import 'package:screenshots/src/utils.dart' as utils;
import 'package:screenshots/src/utils.dart';
import 'package:screenshots/src/validate.dart' as validate;
import 'package:test/test.dart';

import 'src/common.dart';

void main() {
  group('screenshots tests', () {
    test('screen info for device: Nexus 5X', () async {
      final expected = {
        'resources': {
          'statusbar white': 'resources/android/1080/statusbar.png',
          'statusbar': 'resources/android/1080/statusbar.png',
          'navbar': 'resources/android/1080/navbar.png',
          'frame': 'resources/android/phones/Nexus_5X.png',
          'statusbar black': 'resources/android/1080/statusbar.png'
        },
        'destName': 'phone',
        'resize': '80%',
        'devices': ['Nexus 5X'],
        'offset': '-4-9',
        'size': '1080x1920'
      };
      final screens = Screens();
      await screens.init();
      final screen = screens.getScreen('Nexus 5X');
      expect(screen, expected);
    });

    test('screen info for device: iPhone X', () async {
      final expected = {
        'resources': {
          'statusbar white': 'resources/ios/1125/statusbar_white.png',
          'statusbar': 'resources/ios/1125/statusbar_white.png',
          'frame': 'resources/ios/phones/Apple iPhone X Silver.png',
          'statusbar black': 'resources/ios/1125/statusbar_black.png'
        },
        'resize': '87%',
        'devices': ['iPhone X', 'iPhone XS', 'iPhone Xs'],
        'offset': '-0-0',
        'size': '1125x2436'
      };
      final screens = Screens();
      await screens.init();
      final screen = screens.getScreen('iPhone X');
      expect(screen, expected);
    });

    test('overlay statusbar', () async {
      final Screens screens = Screens();
      await screens.init();
      final screen = screens.getScreen('Nexus 6P');
      final Config config = Config(configPath: 'test/screenshots_test.yaml');
      final Map scrnResources = screen['resources'];
      await resources.unpackImages(scrnResources, '/tmp/screenshots');
      final statusbarPath =
          '${config.stagingDir}/${scrnResources['statusbar']}';
      final screenshotPath = 'test/resources/0.png';
      final options = {
        'screenshotPath': screenshotPath,
        'statusbarPath': statusbarPath,
      };
      await im.convert('overlay', options);
      cmd(['git', 'checkout', screenshotPath]);
    }, skip: true);

    test('append navbar', () async {
      final Screens screens = Screens();
      await screens.init();
      final screen = screens.getScreen('Nexus 9');
      final Config config = Config(configPath: 'test/screenshots_test.yaml');
      final Map scrnResources = screen['resources'];
      await resources.unpackImages(scrnResources, '/tmp/screenshots');
      final screenshotNavbarPath =
          '${config.stagingDir}/${scrnResources['navbar']}';
      final screenshotPath = 'test/resources/nexus_9_0.png';
      final options = {
        'screenshotPath': screenshotPath,
        'screenshotNavbarPath': screenshotNavbarPath,
      };
      await im.convert('append', options);
      cmd(['git', 'checkout', screenshotPath]);
    }, skip: true);

    test('frame screenshot', () async {
      final Screens screens = Screens();
      await screens.init();
      final screen = screens.getScreen('Nexus 9');
      final Config config = Config(configPath: 'test/screenshots_test.yaml');
      final Map scrnResources = screen['resources'];
      await resources.unpackImages(scrnResources, '/tmp/screenshots');
      final framePath = config.stagingDir + '/' + scrnResources['frame'];
      final size = screen['size'];
      final resize = screen['resize'];
      final offset = screen['offset'];
      final screenshotPath = 'test/resources/nexus_9_0.png';
      final options = {
        'framePath': framePath,
        'size': size,
        'resize': resize,
        'offset': offset,
        'screenshotPath': screenshotPath,
        'backgroundColor': ImageProcessor.kDefaultAndroidBackground,
      };
      await im.convert('frame', options);
      cmd(['git', 'checkout', screenshotPath]);
    }, skip: true);

    test('parse json xcrun simctl list devices', () {
      final expected = {
        'iOS 11.2': [
          {
            'state': 'Shutdown',
            'availability': '(available)',
            'name': 'iPhone 7 Plus',
            'udid': '1DD6DBF1-846F-4644-8E97-76175788B9A5'
          }
        ],
        'iOS 11.1': [
          {
            'state': 'Shutdown',
            'availability': '(available)',
            'name': 'iPhone 7 Plus',
            'udid': 'BF17CEF1-A6B7-4689-96A2-CE9C271D5F16'
          }
        ]
      };
      final iosDevices = utils.getIosSimulators();
      final iPhone7Plus = iosDevices['iPhone 7 Plus'];
      expect(iPhone7Plus, expected);
    }, skip:     true  );

    test('get highest and available version of ios device', () {
      final expected = {
        'state': 'Shutdown',
        'availability': '(available)',
        'name': 'iPhone 7 Plus',
        'udid': '1DD6DBF1-846F-4644-8E97-76175788B9A5'
      };
      final iosDevices = utils.getIosSimulators();
      final deviceName = 'iPhone 7 Plus';
//    final deviceName = 'iPhone 5c';
      final highestDevice =
          utils.getHighestIosSimulator(iosDevices, deviceName);
      expect(highestDevice, expected);
    }, skip:     true  );

    test('read resource and write to path', () async {
      final scrnResources = [
        'resources/android/1080/statusbar.png',
        'resources/android/1080/navbar.png',
        'resources/android/phones/Nexus_5X.png'
      ];
      final dest = '/tmp';
      for (String resource in scrnResources) {
        await resources.writeImage(
            await resources.readResourceImage(resource), '$dest/$resource');
      }
    });

    test('unpack images', () async {
      final scrnResources = {
        'A': 'resources/android/1080/statusbar.png',
        'B': 'resources/android/1080/navbar.png',
        'C': 'resources/android/phones/Nexus_5X.png'
      };
      final dest = '/tmp';
      await resources.unpackImages(scrnResources, dest);
    }, skip: true);

    test('rooted emulator', () async {
      final emulatorId = 'Nexus_5X_API_27';
      final stagingDir = '/tmp/tmp';
      await resources.unpackScripts(stagingDir);
      final daemonClient = DaemonClient();
      await daemonClient.start;
      final deviceId = await daemonClient.launchEmulator(emulatorId);
      final result = cmd(['adb', 'root']);
      expect(result, 'adbd cannot run as root in production builds\n');
      expect(
          await run.shutdownAndroidEmulator(daemonClient, deviceId), deviceId);
    }, skip:     true  );

//    test('get emulator id from device name', () {
//      final _emulators = utils.getAvdNames();
////    print(_emulators);
//      final emulator =
//          _emulators.firstWhere((emulator) => emulator.contains('Nexus_5X'));
//      expect(emulator, 'Nexus_5X_API_27');
//    }, skip:     true  );

    test('move files', () async {
      final fileName = 'filename';
      final srcDir = '/tmp/tmp1/multiple/levels/deep';
      final dstDir = '/tmp/tmp2/more/levels/deep';

      await File('$srcDir/$fileName').create(recursive: true);
      utils.moveFiles(srcDir, dstDir);
      expect(await File(dstDir + '/' + fileName).exists(), true);
    });

    test('start/stop emulator', () async {
      final expected = {
        'id': 'emulator-5554',
        'name': 'Android SDK built for x86',
        'platform': 'android-x86',
        'emulator': true,
        'category': 'mobile',
        'platformType': 'android',
        'ephemeral': true
      };
      final emulatorName = 'Nexus 6P';
      final emulatorId = 'Nexus_6P_API_28';
      final daemonClient = DaemonClient();
//    daemonClient.verbose = true;
      await daemonClient.start;
      final deviceId = await daemonClient.launchEmulator(emulatorId);
      final devices = await daemonClient.devices;
      final startedDevice = (devices, emulatorName) => devices.firstWhere(
          (device) => device['emulator'] == true,
          orElse: () => null);
      expect(startedDevice(devices, emulatorName), expected);
      expect(
          await run.shutdownAndroidEmulator(daemonClient, deviceId), deviceId);
      expect(startedDevice(await daemonClient.devices, emulatorName), null);
    }, skip:     true  );

    test('change android locale', () async {
      final deviceName = 'Nexus 6P';
      final emulatorId = 'Nexus_6P_API_28';
      final origLocale = 'en_US';
      final newLocale = 'fr_CA';
      final daemonClient = DaemonClient();
      await daemonClient.start;
//    daemonClient.verbose = true;
      final deviceId = await daemonClient.launchEmulator(emulatorId);
//    print('switching to $newLocale locale');
      run.changeAndroidLocale(deviceId, deviceName, newLocale);
      // wait for locale to change
      await utils.waitAndroidLocaleChange(deviceId, newLocale);
      // change back for repeated testing
//    print('switching to $origLocale locale');
      run.changeAndroidLocale(deviceId, deviceName, origLocale);
      await utils.waitAndroidLocaleChange(deviceId, origLocale);
      expect(
          await run.shutdownAndroidEmulator(daemonClient, deviceId), deviceId);
    }, timeout: Timeout(Duration(seconds: 180)), skip:     true  );

    test('start/stop simulator', () async {
      final simulatorName = 'iPhone X';
      final simulatorInfo =
          utils.getHighestIosSimulator(utils.getIosSimulators(), simulatorName);
      final deviceId = simulatorInfo['udid'];
      final daemonClient = DaemonClient();
//    daemonClient.verbose = true;
      await daemonClient.start;
      await run.startSimulator(daemonClient, deviceId);
      await run.shutdownSimulator(deviceId);
      await daemonClient.stop;
    }, skip:     true  );

    test('start emulator on travis', () async {
      final androidHome = Platform.environment['ANDROID_HOME'];
      final emulatorName = 'Nexus_6P_API_27';
      await streamCmd(
        [
          '$androidHome/emulator/emulator',
          '-avd',
          emulatorName,
          '-no-audio',
          '-no-window',
          '-no-snapshot',
          '-gpu',
          'swiftshader',
        ],
//        ProcessStartMode.detached
      );
    }, skip: true);

    test('change locale on android and test', () async {
      final emulatorId = 'Nexus_6P_API_28';
      final deviceName = 'any device name';
      final stagingDir = '/tmp/tmp';
      final origLocale = 'en_US';
      final newLocale = 'fr_CA';
      final testAppDir = 'example';
      final testAppSrcPath = 'test_driver/main.dart';

      // unpack resources
      await resources.unpackScripts(stagingDir);

      final daemonClient = DaemonClient();
      await daemonClient.start;

      // start emulator
      final deviceId = await daemonClient.launchEmulator(emulatorId);

      // change locale
      await run.setEmulatorLocale(deviceId, newLocale, deviceName);

      // run test
      await streamCmd(['flutter', 'drive', testAppSrcPath],
          workingDirectory: testAppDir);

      // restore orig locale
      await run.setEmulatorLocale(deviceId, origLocale, deviceName);

      // stop emulator
      expect(
          await run.shutdownAndroidEmulator(daemonClient, deviceId), deviceId);
    }, timeout: Timeout(Duration(seconds: 90)), skip:     true  );

    test('get android device locale', () async {
      final emulatorId = 'Nexus_6P_API_28';
      final stagingDir = '/tmp/tmp';
      final locale = 'en_US';

      await resources.unpackScripts(stagingDir);
      final daemonClient = DaemonClient();
      await daemonClient.start;
      final deviceId = await daemonClient.launchEmulator(emulatorId);
      final deviceLocale = utils.getAndroidDeviceLocale(deviceId);
      expect(
          await run.shutdownAndroidEmulator(daemonClient, deviceId), deviceId);

      expect(deviceLocale, locale);
    }, skip:     true  );

    test('change locale on iOS and test', () async {
      final simulatorName = 'iPhone X';
      final stagingDir = '/tmp/tmp';
      final origLocale = 'en_US';
      final locale = 'fr_CA';
      final testAppDir = 'example';
      final testAppSrcPath = 'test_driver/main.dart';

      // unpack resources
      await resources.unpackScripts(stagingDir);

      final daemonClient = DaemonClient();
      await daemonClient.start;

      // change locale
      final simulatorInfo =
          utils.getHighestIosSimulator(utils.getIosSimulators(), simulatorName);
      final deviceId = simulatorInfo['udid'];
      await run.setSimulatorLocale(
          deviceId, simulatorName, locale, stagingDir, daemonClient);

      // start simulator
      await run.startSimulator(daemonClient, deviceId);

      // run test
      await streamCmd(['flutter', '-d', deviceId, 'drive', testAppSrcPath],
          workingDirectory: testAppDir);

      // stop simulator
      await run.shutdownSimulator(deviceId);

      // restore orig locale
      await run.setSimulatorLocale(
          deviceId, simulatorName, origLocale, stagingDir, daemonClient);
    }, timeout: Timeout(Duration(seconds: 90)), skip:     true  );

    test('get ios simulator locale', () async {
      final udId = '03D4FC12-3927-4C8B-A226-17DE34AE9C18';
      var locale = utils.getIosSimulatorLocale(udId);
      expect(locale, 'en-US');
    }, skip:     true  );

//    test('get avd from a running emulator', () async {
//      final expectedId = 'Nexus_6P_API_28';
//      final daemonClient = DaemonClient();
//      await daemonClient.start;
//      // start emulator
//      final deviceId = await daemonClient.launchEmulator(expectedId);
//      final emulatorId = utils.getAndroidEmulatorId(deviceId);
//      expect(emulatorId, expectedId);
//      expect(
//          await run.shutdownAndroidEmulator(daemonClient, deviceId), deviceId);
//    }, skip:     true  );

    test('get real devices', () async {
      final expected = [
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
      final daemonClient = DaemonClient();
      await daemonClient.start;
      final devices = await daemonClient.devices;
      final iosDevices = utils.getIosDaemonDevices(devices);
      final androidDevices = utils.getAndroidDevices(devices);
      expect(androidDevices, []);
      expect(iosDevices, expected);
    }, skip:     true  );

    test('get devices', () {
      final expected = loadDaemonDevice({
        'id': '3b3455019e329e007e67239d9b897148244b5053',
        'name': 'Maurice’s iPhone',
        'platform': 'ios',
        'emulator': false,
        'model': 'iPhone 5c (GSM)'
      });
      String deviceName = 'iPhone 5c';
      DaemonDevice device = utils.getDevice([expected], deviceName);
      expect(device, expected);
      final isDeviceAttached = (device) => device != null;
      expect(isDeviceAttached(device), true);
      deviceName = 'iPhone X';
      device = utils.getDevice([expected], deviceName);
      expect(device, null);
      expect(isDeviceAttached(device), false);
    });

    test('get device type from config', () {
      final deviceName = 'Nexus 9P';
      final expected = DeviceType.android;
      final config = '''
      devices:
        ios:
          iPhone X:
        android:
          $deviceName:
      frame: true
      ''';

      final configInfo = Config(configStr: config);
      DeviceType deviceType = run.getDeviceType(configInfo, deviceName);
      expect(deviceType, expected);
    });

    test('get adb props, and show diffs', () async {
      final expected = {
        'added': {'xxx': 'yyy'},
        'removed': {'wifi.direct.interface': 'p2p-dev-wlan0'},
        'changed': {
          'orig': {'xmpp.auto-presence': 'true'},
          'new': {'xmpp.auto-presence': false}
        }
      };
      final emulatorId = 'Nexus_6P_API_28';

      final daemonClient = DaemonClient();
      await daemonClient.start;
      // start emulator
      final deviceId = await daemonClient.launchEmulator(emulatorId);

      Map props = getDeviceProps(deviceId);
      final newProps = Map.from(props);
      newProps['xmpp.auto-presence'] = false; //changed
      newProps['xxx'] = 'yyy'; // added
      newProps.remove('wifi.direct.interface'); // removed

      final Map diffs = diffMaps(props, newProps);
      expect(diffs, expected);
      expect(
          await run.shutdownAndroidEmulator(daemonClient, deviceId), deviceId);
    }, skip:     true  );

    group('ProcessWrapper', () {
      test('works in conjunction with subscribers to stdio streams', () async {
        final expected = 'README.md';
        final delegate = await Process.start('ls', ['-la']);
        final process = ProcessWrapper(delegate);
        final readme = await process.stdout
            .transform<String>(utf8.decoder)
            .transform<String>(const LineSplitter())
            .firstWhere((line) => line.contains(expected));
        expect(readme.contains(expected), isTrue);
      });

      test('scan syslog for string', () async {
        final toLocale = 'en_US';
//      final expected =
//          'ContactsProvider: Locale has changed from [fr_CA] to [en_US]';
//      final expected = RegExp('Locale has changed from');
        final expected = RegExp(r'.*');
        final daemonClient = DaemonClient();
        await daemonClient.start;
        final emulatorId = 'Nexus_6P_API_28';
        final deviceId = await daemonClient.launchEmulator(emulatorId);
        var actual = await utils.waitSysLogMsg(deviceId, expected, toLocale);
//      print('actual=$actual');
        expect(actual?.contains(expected), isTrue);
        expect(await run.shutdownAndroidEmulator(daemonClient, deviceId),
            deviceId);
      }, skip:     true  );

      test('reg exp', () {
        final locale = 'fr_CA';
        final line =
            'ContactsProvider: Locale has changed from [en_US] to [${locale.replaceFirst('-', '_')}]';
//      final regExp = RegExp(
//          'ContactsProvider: Locale has changed from .* to [fr_CA]',
//          dotAll: true);
        final regExp = RegExp(
            'ContactsProvider: Locale has changed from .* to \\[${locale.replaceFirst('-', '_')}\\]');
        expect(regExp.stringMatch(line), line);
        expect(regExp.hasMatch(line), true);
      });
    });

    group('recording, comparison', () {
      test('recording mode', () async {
        final origDir = Directory.current;
        Directory.current = 'example';
        final configPath = 'screenshots.yaml';
        await run.screenshots(
            configPath: configPath,
            mode: utils.getStringFromEnum(RunMode.recording));
        final config = Config(configPath: configPath);
        final recordingDir = config.recordingDir;
        expect(await utils.isRecorded(recordingDir), isTrue);
        Directory.current = origDir;
      }, timeout: Timeout(Duration(seconds: 180)), skip:     true  );

      test('imagemagick compare', () {
        final recordedImage0 = 'test/resources/recording/Nexus 6P-0.png';
        final comparisonImage0 = 'test/resources/comparison/Nexus 6P-0.png';
        final comparisonImage1 = 'test/resources/comparison/Nexus 6P-1.png';
        final goodPair = {
          'recorded': recordedImage0,
          'comparison': comparisonImage0
        };
        final badPair = {
          'recorded': recordedImage0,
          'comparison': comparisonImage1
        };
        final pairs = {'good': goodPair, 'bad': badPair};

        pairs.forEach((behave, pair) async {
          final recordedImage = pair['recorded']!;
          final comparisonImage = pair['comparison']!;
          var doCompare = await runInContext<bool>(() async {
            return im.compare(comparisonImage, recordedImage);
          });
          behave == 'good'
              ? Null
              : File(im.getDiffImagePath(comparisonImage)).deleteSync();
          behave == 'good' ? expect(doCompare, true) : expect(doCompare, false);
        });
      });

      test('comparison mode', () async {
        final origDir = Directory.current;
        Directory.current = 'example';
        final configPath = 'screenshots.yaml';
        final config = Config(configPath: configPath);
        final recordingDir = config.recordingDir;
        expect(await utils.isRecorded(recordingDir), isTrue);
        await run.screenshots(
            configPath: configPath,
            mode: utils.getStringFromEnum(RunMode.comparison));
        Directory.current = origDir;
      }, timeout: Timeout(Duration(seconds: 180)), skip:     true  );

      test('cleanup diffs at start of normal run', () {
        final fastlaneDir = 'test/resources/comparison';
        Directory(fastlaneDir).listSync().forEach((fsEntity) =>
            File(im.getDiffImagePath(fsEntity.path)).createSync());
        expect(
            Directory(fastlaneDir).listSync().where((fileSysEntity) => p
                .basename(fileSysEntity.path)
                .contains(ImageMagick.kDiffSuffix)),
            isNotEmpty);
        im.deleteDiffs(fastlaneDir);
        expect(
            Directory(fastlaneDir).listSync().where((fileSysEntity) => p
                .basename(fileSysEntity.path)
                .contains(ImageMagick.kDiffSuffix)),
            isEmpty);
      });
    });

    group('archiving', () {
      test('run with archiving enabled', () async {
        final origDir = Directory.current;
        Directory.current = 'example';
        final configPath = 'screenshots.yaml';
        await run.screenshots(
            configPath: configPath,
            mode: utils.getStringFromEnum(RunMode.archive));
        Directory.current = origDir;
      }, timeout: Timeout(Duration(seconds: 180)), skip:     true  );
    });

    group('fastlane dirs', () {
      test('delete files matching a pattern', () async {
        final dirPath = 'test/resources/test';
        final deviceId = 'Nexus 6P';
        final pattern = RegExp('$deviceId.*.$kImageExtension');
        final filesPresent = (dirPath, pattern) => Directory(dirPath)
            .listSync()
            .toList()
            .where((e) => pattern.hasMatch(p.basename(e.path)));
        expect(filesPresent(dirPath, pattern).length, 2);
        deleteMatchingFiles(dirPath, pattern);
        expect(filesPresent(dirPath, pattern), isEmpty);
        // restore deleted files
        await runInContext<String>(() async {
          return cmd(['git', 'checkout', dirPath]);
        });
      });

      test('get android model type', () async {
        final defaultPhone = 'default phone';
        final defaultSevenInch = 'default seven inch';
        final defaultTenInch = 'default ten inch';
        final unknownDevice = 'unknown device';
        final phones = {
          defaultPhone: kFastlanePhone,
          unknownDevice: kFastlanePhone,
          'Nexus 5X': kFastlanePhone,
          'Nexus 6': kFastlanePhone,
          'Nexus 6P': kFastlanePhone,
        };
        final sevenInches = {defaultSevenInch: kFastlaneSevenInch};
        final tenInches = {
          defaultTenInch: kFastlaneTenInch,
          'Nexus 9': kFastlaneTenInch
        };
        final androidDeviceNames = phones
          ..addAll(sevenInches)
          ..addAll(tenInches);
        final screens = Screens();
        await screens.init();
        for (final androidDeviceName in androidDeviceNames.keys) {
          final screenProps = screens.getScreen(androidDeviceName);
          expect(getAndroidModelType(screenProps, androidDeviceName),
              androidDeviceNames[androidDeviceName]);
        }

        // confirm handling of unknown device
        final screenProps = screens.getScreen(unknownDevice);
        expect(screenProps, isNull);
        expect(getAndroidModelType(screenProps, unknownDevice), kFastlanePhone);
      }, skip:     true  );
    });

//    group('adb path', () {
//      test('find adb path', () async {
//        final _adbPath = getAdbPath(androidSdk);
////      print('adbPath=$_adbPath');
//      }, skip:     true  );
//    });

    group('manage device orientation', () {
      test('find ios simulator orientation', () async {
        final udId = '03D4FC12-3927-4C8B-A226-17DE34AE9C18';
        final env = Platform.environment;
        final preferencesDir =
            '${env['HOME']}/Library/Developer/CoreSimulator/Devices/$udId/data/Library/Preferences';
        Directory(preferencesDir).listSync().forEach((fsEntity) {
          // print contents
          final filePath = fsEntity.path;
//        print('filePath=$filePath');
          try {
            cmd(['plutil', '-convert', 'xml1', '-r', '-o', '-', filePath]);
//          print('contents=$contents');
          } catch (e) {
            print('error: $e');
          }
        });
      }, skip:     true  );

      test('set ios simulator orientation', () async {
        final scriptDir = 'lib/resources/script';
        final simulatorName = 'iPhone 7 Plus';
        final simulatorInfo = utils.getHighestIosSimulator(
            utils.getIosSimulators(), simulatorName);
        final deviceId = simulatorInfo['udid'];
        final daemonClient = DaemonClient();
//      daemonClient.verbose = true;
        await daemonClient.start;
        await run.startSimulator(daemonClient, deviceId);
        await Future.delayed(Duration(milliseconds: 5000)); // finish booting
        orient.changeDeviceOrientation(
            DeviceType.ios, orient.Orientation.LandscapeRight,
            scriptDir: scriptDir);
        await Future.delayed(Duration(milliseconds: 3000));
        orient.changeDeviceOrientation(
            DeviceType.ios, orient.Orientation.Portrait,
            scriptDir: scriptDir);
        await Future.delayed(Duration(milliseconds: 1000));
        await run.shutdownSimulator(deviceId);
        await daemonClient.stop;
      }, skip:     true  );

      test('set android emulator orientation', () async {
        final emulatorId = 'Nexus_6P_API_28';
        final daemonClient = DaemonClient();
        await daemonClient.start;
        final deviceId = await daemonClient.launchEmulator(emulatorId);
        orient.changeDeviceOrientation(
            DeviceType.android, orient.Orientation.LandscapeRight,
            deviceId: deviceId);
        await Future.delayed(Duration(milliseconds: 3000));
        orient.changeDeviceOrientation(
            DeviceType.android, orient.Orientation.Portrait,
            deviceId: deviceId);
        await Future.delayed(Duration(milliseconds: 3000));
        expect(await run.shutdownAndroidEmulator(daemonClient, deviceId),
            deviceId);
      }, skip:     true  );
    });

    group('config validate', () {
      test('config guide', () async {
        final Screens screens = Screens();
        await screens.init();
        final daemonClient = DaemonClient();
        await daemonClient.start;
        validate.deviceGuide(screens, await daemonClient.devices,
            await daemonClient.emulators, 'screenshots.yaml');
      }, skip:     true  );

      test('validate device params', () {
        final deviceName = 'ios device 1';
        final orientation = 'Portrait';
        final frame = true;
        final params = '''
      devices:
        ios:
          $deviceName:
            orientation: $orientation
            frame: $frame
          ios device 2:
        android:
          android device 1:
          android device 2:
        fuschia:
      frame: true
      ''';
        final configInfo = Config(configStr: params);
        final deviceNames = configInfo.deviceNames;
        for (final devName in deviceNames) {
          final deviceInfo = configInfo.getDevice(devName);
//        print('devName=$devName');
//        print('deviceInfo=$deviceInfo');
          if (deviceInfo != null) {
            if (deviceInfo.name == deviceName) {
              expect(utils.getEnumFromString(Orientation.values, orientation),
                  deviceInfo.orientations[0]);
//              expect(validate.isValidOrientation(orientation), isTrue);
//              expect(validate.isValidOrientation('bad orientation'), isFalse);
            }
            expect(deviceInfo.isFramed, frame);
            expect(validate.isValidFrame(frame), isTrue);
            expect(validate.isValidFrame('bad frame'), isFalse);
          }
        }
      });

//      test('valid values for params', () {
////      print(Orientation.values);
//        for (final orientation in Orientation.values) {
////        print('${utils.getStringFromEnum(orientation)}');
//        }
//      });
    });

    group('flavors', () {
      test('flavor run', () async {
        final flavor = 'paid';
        final origDir = Directory.current;
        Directory.current = 'flavors';
        final configPath = 'screenshots.yaml';
        await run.screenshots(
            configPath: configPath,
            mode: utils.getStringFromEnum(RunMode.normal),
            flavor: flavor);
        Directory.current = origDir;
      }, timeout: Timeout(Duration(seconds: 240)), skip:     true  );
    });

    group('run across platforms', () {
      test('ios only', () async {
        final configIosOnly = '''
        tests:
          - test_driver/main.dart
        staging: /tmp/screenshots
        locales:
          - en-US
        devices:
          ios:
            iPhone X:
        frame: false
      ''';
        // for this test change directory
        final origDir = Directory.current;
        Directory.current = 'example';
        final screenshots = Screenshots(configStr: configIosOnly);
        expect(await screenshots.run(), isTrue);
        // allow other tests to continue
        Directory.current = origDir;
      }, timeout: Timeout(Duration(minutes: 4)), skip:     true  );

      test('find highest avd', () async {
        final emulatorName = 'Nexus 6P';
        final expected = {
          'id': 'Nexus_6P_API_30',
          'name': 'Nexus 6P',
          'category': 'mobile',
          'platformType': 'android'
        };
        final daemonClient = DaemonClient();
        await daemonClient.start;
        final emulators = await daemonClient.emulators;
        final emulator = utils.findEmulator(emulators, emulatorName);
        expect(emulator, expected);
      }, skip:     true  );

      test('find a running device', () {
        // note: expects a running emulator
        final androidDeviceName = 'Nexus 6P';
        final iosDeviceName = 'iPhone 5c';
        final androidDevice = {
          'id': 'emulator-5554',
          'name': 'Android SDK built for x86',
          'platform': 'android-x86',
//        'emulator': true, // seems to misbehave on some emulators
          'emulator': false,
          'category': 'mobile',
          'platformType': 'android',
          'ephemeral': true
        };
        final iosDevice = {
          'id': '3b3455019e329e007e67239d9b897148244b5053',
          'name': 'Maurice’s iPhone',
          'platform': 'ios',
          'emulator': false,
          'category': 'mobile',
          'platformType': 'ios',
          'ephemeral': true,
          'model': 'iPhone 5c (GSM)'
        };
        final runningDevices = [
          loadDaemonDevice(androidDevice),
          loadDaemonDevice(iosDevice)
        ];
        final installedEmulators = [
          loadDaemonEmulator({
            'id': 'Nexus_6P_API_28',
            'name': 'Nexus 6P',
            'category': 'mobile',
            'platformType': 'android'
          }),
          loadDaemonEmulator({
            'id': 'Nexus_6P_API_30',
            'name': 'Nexus 6P',
            'category': 'mobile',
            'platformType': 'android'
          }),
          loadDaemonEmulator({
            'id': 'apple_ios_simulator',
            'name': 'iOS Simulator',
            'category': 'mobile',
            'platformType': 'ios'
          })
        ];
        DaemonDevice deviceInfo = run.findRunningDevice(
            runningDevices, installedEmulators, androidDeviceName);
        expect(deviceInfo, androidDevice);
        deviceInfo = run.findRunningDevice(
            runningDevices, installedEmulators, iosDeviceName);
        expect(deviceInfo, iosDevice);
      }, skip:     true  );
    });

    group('paths', () {
      test('convert', () {
        final paths = [
          {'path': '/a/b/c', 'posix': 'a/b/c', 'windows': 'a\\b\\c'},
          {'path': './a/b/c', 'posix': './a/b/c', 'windows': '.\\a\\b\\c'},
          {'path': 'a/b/c.d', 'posix': 'a/b/c.d', 'windows': 'a\\b\\c.d'},
          {
            'path': './a/b/c.d',
            'posix': './a/b/c.d',
            'windows': '.\\a\\b\\c.d'
          },
          {'path': './a/0.png', 'posix': './a/0.png', 'windows': '.\\a\\0.png'},
        ];
        expect(p.relative(p.current), '.');
        final posixContext = p.Context(style: p.Style.posix);
        final windowsContext = p.Context(style: p.Style.windows);
        for (var path in paths) {
          expect(utils.toPlatformPath(path['path']!, context: posixContext),
              path['posix']);
          expect(utils.toPlatformPath(path['path']!, context: windowsContext),
              path['windows']);
        }
      });
    });
  });
}
