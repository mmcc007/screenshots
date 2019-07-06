import 'dart:async';
import 'dart:io';

import 'config.dart';
import 'daemon_client.dart';
import 'screens.dart';
import 'image_processor.dart';
import 'resources.dart' as resources;
import 'utils.dart' as utils;
import 'fastlane.dart' as fastlane;

/// default config file name
const String kConfigFileName = 'screenshots.yaml';

/// screenshots environment file name
const String kEnvFileName = 'env.json';

/// Distinguish device OS.
enum DeviceType { android, ios }

/// Capture screenshots, process, and load into fastlane according to config file.
///
/// For each locale and emulator/simulator:
///
/// 1. Start the emulator/simulator for current locale.
/// 2. Run each integration test and capture the screenshots.
/// 3. Process the screenshots including adding a frame if required.
/// 4. Move processed screenshots to fastlane destination for upload to stores.
/// 5. Stop emulator/simulator.
Future<void> run([String configPath = kConfigFileName]) async {
  final screens = Screens();
  await screens.init();

  // start flutter daemon
  final daemonClient = DaemonClient();
  await daemonClient.start;
  final devices = await daemonClient.devices;
  final emulators = await daemonClient.emulators;

  final config = Config(configPath);
  // validate config file
  await config.validate(screens, devices);
  final Map configInfo = config.configInfo;

  // init
  final stagingDir = configInfo['staging'];
  await Directory(stagingDir + '/test').create(recursive: true);
  await resources.unpackScripts(stagingDir);
  await fastlane.clearFastlaneDirs(configInfo, screens);

  final imageProcessor = ImageProcessor(screens, configInfo);

  // run integration tests in each android device (or emulator) for each locale and
  // process screenshots
//  await runAll(daemonClient, config, screens, imageProcessor, devices);
  await runTestsOnAll(
      daemonClient, devices, emulators, config, screens, imageProcessor);
  // shutdown daemon
  await daemonClient.stop;

  print('\n\nScreen images are available in:');
  print('  ios/fastlane/screenshots');
  print('  android/fastlane/metadata/android');
  print('for upload to both Apple and Google consoles.');
  print('\nFor uploading and other automation options see:');
  print('  https://pub.dartlang.org/packages/fledge');
  print('\nscreenshots completed successfully.');
}

Future runAll(DaemonClient daemonClient, Config config, Screens screens,
    ImageProcessor imageProcessor, List devices) async {
  final configInfo = config.configInfo;
  final stagingDir = configInfo['staging'];
  // run integration tests in each android device (or emulator) for each locale and
  // process screenshots
  if (configInfo['devices']['android'] != null) {
    for (final deviceName in configInfo['devices']['android'].keys) {
      final highestAvdName = utils.getHighestAVD(deviceName);
      // find first running emulator that is using this avd (if any)
      final deviceId = utils.findAndroidDeviceId(highestAvdName);
      final alreadyBooted = deviceId == null ? false : true;

      for (final locale in configInfo['locales']) {
        final freshDeviceId = await emulator(daemonClient, deviceName, true,
            deviceId, stagingDir, highestAvdName, alreadyBooted, locale);

        // store env for later use by tests
        await config.storeEnv(screens, deviceName, locale, 'android');

        for (final testPath in configInfo['tests']) {
          print(
              'Capturing screenshots with test app $testPath on emulator \'$deviceName\' in locale $locale ...');

          await screenshots(freshDeviceId, testPath, stagingDir);
          // process screenshots
          await imageProcessor.process(DeviceType.android, deviceName, locale);
        }
        if (!alreadyBooted) {
          await emulator(daemonClient, deviceName, false, freshDeviceId,
              stagingDir, highestAvdName);
        }
      }
    }
  }

  // run integration tests in each ios simulator for each locale and
  // process screenshots
  if (configInfo['devices']['ios'] != null) {
    for (final simulatorName in configInfo['devices']['ios'].keys) {
      final simulatorInfo =
          utils.getHighestIosSimulator(utils.getIosSimulators(), simulatorName);
      for (final locale in configInfo['locales']) {
        if (simulatorInfo != null)
          await simulator(
              simulatorName, true, simulatorInfo, stagingDir, locale);

        // store env for later use by tests
        await config.storeEnv(screens, simulatorName, locale, 'ios');

        for (final testPath in configInfo['tests']) {
          print(
              'Capturing screenshots with test app $testPath on simulator \'$simulatorName\' in locale $locale ...');
          String deviceId;
          if (simulatorInfo == null)
            deviceId = getDevice(devices, simulatorName)['id'];
          else
            deviceId = simulatorInfo['udid'];
          await screenshots(deviceId, testPath, stagingDir);
          // process screenshots
          await imageProcessor.process(DeviceType.ios, simulatorName, locale);
        }
        if (simulatorInfo != null)
          await simulator(simulatorName, false, simulatorInfo);
      }
    }
  }
}

Map getDevice(List devices, String deviceName) {
  return devices.firstWhere(
      (device) => device['model'] == null
          ? device['name'] == deviceName
          : device['model'].contains(deviceName),
      orElse: () => throw '$deviceName not found');
}

///
/// Run the screenshot integration test on current emulator or simulator.
///
/// Test is expected to generate a sequential number of screenshots.
/// (to match order of appearance is Apple and Google stores)
///
/// Assumes the integration test captures the screen shots into a known directory using
/// provided [capture_screen.screenshot()].
///
void screenshots(String deviceId, String testPath, String stagingDir) async {
  // clear existing screenshots from staging area
  utils.clearDirectory('$stagingDir/test');
  // run the test
  await utils.streamCmd('flutter', ['-d', deviceId, 'drive', testPath]);
}

///
/// Start/stop emulator.
///
Future<String> emulator(DaemonClient daemonClient, String deviceName,
    bool start, String deviceId, String stagingDir, String avdName,
    [bool alreadyBooted, String testLocale = "en-US"]) async {
  // used to keep and report a newly booted device if any
  String freshDeviceId = deviceId;

  if (start) {
    if (alreadyBooted) {
      print('Using running emulator \'$deviceName\' in locale $testLocale ...');
    } else {
      print('Starting emulator \'$deviceName\' in locale $testLocale ...');
      if (Platform.environment['CI'] == 'true') {
        // testing on CI/CD requires starting emulator in a specific way
        await startAndroidEmulatorOnCI(avdName, stagingDir);
      } else {
        // testing locally, so start emulator in normal way
        await daemonClient.launchEmulator(avdName);
      }

      // get fresh id of emulator just booted in this run.
      freshDeviceId = await _getFreshDeviceId(deviceId, deviceName);

      // confirm fully booted before continuing (or getting locale may not work)
      await utils.streamCmd(
          '$stagingDir/resources/script/android-wait-for-emulator', []);
    }

    // change locale
    setAndroidLocale(freshDeviceId, deviceName, testLocale);
    // note: there should be enough time for the emulator to (re)start
    // while app is being compiled.

  } else {
    print('Stopping emulator: \'$deviceName\' ...');
    if (deviceId == null) {
      throw 'Error: unknown deviceId';
    }
    await utils.stopEmulator(deviceId, stagingDir);
  }
  return freshDeviceId;
}

Future startAndroidEmulatorOnCI(String emulatorId, String stagingDir) async {
  // testing on CI/CD requires starting emulator in a specific way
  final androidHome = Platform.environment['ANDROID_HOME'];
  await utils.streamCmd(
      '$androidHome/emulator/emulator',
      [
        '-avd',
        emulatorId,
        '-no-audio',
        '-no-window',
        '-no-snapshot',
        '-gpu',
        'swiftshader',
      ],
      '.',
      ProcessStartMode.detached);
  // wait for emulator to start
  await utils
      .streamCmd('$stagingDir/resources/script/android-wait-for-emulator', []);
}

void setAndroidLocale(String deviceId, String deviceName, String testLocale) {
  String deviceLocale = utils.androidDeviceLocale(deviceId);
  if (deviceLocale != testLocale) {
    print(
        'Changing locale from $deviceLocale to $testLocale on \'$deviceName\'...');
    if (utils.cmd('adb', ['root'], '.', true) ==
        'adbd cannot run as root in production builds\n') {
      stdout.write(
          'Warning: locale will not be changed. Running in locale \'$deviceLocale\'.\n');
      stdout.write(
          'To change locale you must use a non-production emulator (one that does not depend on Play Store). See:\n');
      stdout.write(
          '    https://stackoverflow.com/questions/43923996/adb-root-is-not-working-on-emulator/45668555#45668555 for details.\n');
    }
    flutterDriverBugWarning();
    // adb shell "setprop persist.sys.locale fr-CA; setprop ctl.restart zygote"
    utils.cmd('adb', [
      '-s',
      deviceId,
      'shell',
      'setprop',
      'persist.sys.locale',
      testLocale,
      ';',
      'setprop',
      'ctl.restart',
      'zygote'
    ]);
  }
}

Future<String> _getFreshDeviceId(String deviceId, String deviceName) async {
  String freshDeviceId;
  deviceId == null
      ? freshDeviceId = await utils.getBootedAndroidDeviceId(deviceName)
      : freshDeviceId = deviceId;
  if (freshDeviceId == null) {
    throw 'Error: unknown deviceId';
  }
  return freshDeviceId;
}

///
/// Start/stop simulator.
///
Future<void> simulator(String name, bool start, Map simulatorInfo,
    [String stagingDir, String testLocale = 'en-US']) async {
  final udId = simulatorInfo['udid'];
  final isAlreadyBooted = simulatorInfo['state'] == 'Booted';
  if (start) {
    if (isAlreadyBooted) {
      print('Restarting simulator \'$name\' in locale $testLocale ...');
      utils.cmd('xcrun', ['simctl', 'shutdown', udId]);
    } else {
      print('Starting simulator \'$name\' in locale $testLocale ...');
    }
    final simulatorLocale = utils.iosSimulatorLocale(udId);
    if (simulatorLocale != testLocale) {
      print(
          'Changing locale from $simulatorLocale to $testLocale on \'$name\'...');
      flutterDriverBugWarning();

      await utils.streamCmd('$stagingDir/resources/script/simulator-controller',
          [name, 'locale', testLocale]);
    }
    utils.cmd('xcrun', ['simctl', 'boot', udId]);
  } else {
    if (!isAlreadyBooted) {
      print('Stopping simulator: \'$name\' ...');
      utils.cmd('xcrun', ['simctl', 'shutdown', udId]);
    }
  }
}

void flutterDriverBugWarning() {
  stdout.write(
      '\nWarning: running tests in a non-default locale will cause test to hang due to a bug in Flutter Driver (not related to \'screenshots\'). Modify your screenshots.yaml to use only the default locale for your location. For details of bug see comment at https://github.com/flutter/flutter/issues/27785#issue-408955077. Give comment a thumbs-up to get it fixed!\n\n');
}

Future runTestsOnAll(DaemonClient daemonClient, List devices, List emulators,
    Config config, Screens screens, ImageProcessor imageProcessor) async {
  final configInfo = config.configInfo;
  final locales = configInfo['locales'];
  final stagingDir = configInfo['staging'];
  final testPaths = configInfo['tests'];
  final deviceNames = utils.getAllDevices(configInfo);

  for (final deviceName in deviceNames) {
    DeviceType deviceType;
    // look for matching device first
    final device = devices.firstWhere((device) {
      if (device['platform'] == 'ios') {
        deviceType = DeviceType.ios;
        if (device['emulator']) {
          // running ios simulator
          return device['name'] == deviceName;
        } else {
          // real ios device
          return device['model'].contains(deviceName);
        }
      } else {
        deviceType = DeviceType.android;
        if (device['emulator']) {
          // running android emulator
          return findDeviceEmulator(emulators, device['id'])['name'] ==
              deviceName;
        } else {
          // real android device
          return device['name'] == deviceName;
        }
      }
    }, orElse: () => null);

    String deviceId;
    Map emulator = null;
    Map simulator = null;
    if (device != null) {
      deviceId = device['id'];
    } else {
      // if no matching device, look for matching android emulator
      emulator = findEmulator(emulators, deviceName);
      if (emulator != null) {
        deviceType = DeviceType.android;
        final emulatorId = emulator['id'];
        print('Starting $deviceName...');
//        daemonClient.verbose = true;
        await daemonClient.launchEmulator(emulatorId);
//        daemonClient.verbose = false;
        deviceId = utils.findAndroidDeviceId(emulatorId);
        print('... $deviceName started.');
      } else {
        // if no matching android emulator, look for matching ios simulator
        deviceType = DeviceType.ios;
        simulator =
            utils.getHighestIosSimulator(utils.getIosSimulators(), deviceName);
        deviceId = simulator['udid'];
        print('Starting $deviceName...');
//        daemonClient.verbose = true;
        utils.cmd('xcrun', ['simctl', 'boot', deviceId]);
//        daemonClient.verbose = false;
        print('... $deviceName started.');
      }
    }

    for (final locale in locales) {
      // set locale if android device or emulator
      if ((device != null && device['platform'] != 'ios') ||
          (device == null && emulator != null)) {
        // a running android device or emulator
        final deviceLocale = utils.androidDeviceLocale(deviceId);
        print('android device or emulator locale=$deviceLocale');
        if (locale != deviceLocale) {
          print('Changing locale from $deviceLocale to $locale...');
          daemonClient.verbose = true;
          setAndroidLocale(deviceId, deviceName, locale);
          daemonClient.verbose = false;
          print('... locale change complete.');
        }
      }

      // set locale if ios simulator
      if ((device != null &&
              device['platform'] == 'ios' &&
              device['emulator']) ||
          (device == null && simulator != null)) {
        // a running simulator
        final deviceLocale = utils.iosSimulatorLocale(deviceId);
        print('simulator locale=$deviceLocale');
        if (locale != deviceLocale) {
          print('Changing locale from $deviceLocale to $locale');
          daemonClient.verbose = true;
          utils.cmd('xcrun', ['simctl', 'shutdown', deviceId]);
          await utils.streamCmd(
              '$stagingDir/resources/script/simulator-controller',
              [deviceId, 'locale', locale]);
          utils.cmd('xcrun', ['simctl', 'boot', deviceId]);
          daemonClient.verbose = true;
          print('...locale change complete.');
        }
      }

      // issue warning if ios device
      if ((device != null &&
          device['platform'] == 'ios' &&
          !device['emulator'])) {
        // a running ios device
        print('Warning: the locale of an ios device cannot be changed.');
      }

      // store env for later use by tests
      await config.storeEnv(screens, deviceName, locale, 'android');

      // run tests
      for (final testPath in testPaths) {
        print('Running $testPath on \'$deviceName\' in locale $locale...');
        await utils.streamCmd('flutter', ['-d', deviceId, 'drive', testPath]);

        // process screenshots
        await imageProcessor.process(deviceType, deviceName, locale);
      }
    }

    // if an emulator was started, shut it down
    if (emulator != null) {
      await shutdownAndroidEmulator(deviceId, emulator['name']);
    }
    if (simulator != null) {
      print('Waiting for \'$deviceName\' to shutdown...');
      utils.cmd('xcrun', ['simctl', 'shutdown', deviceId]);
      print('... \'$deviceName\' shutdown complete.');
    }
  }
}

Map findEmulator(List emulators, String emulatorName) {
  return emulators.firstWhere((emulator) => emulator['name'] == emulatorName,
      orElse: () => null);
}

Map findDeviceEmulator(List emulators, String deviceId) {
  return emulators.firstWhere(
      (emulator) => emulator['id'] == utils.getAndroidEmulatorId(deviceId),
      orElse: () => null);
}
