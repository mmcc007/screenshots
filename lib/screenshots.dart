import 'dart:async';
import 'dart:io';

import 'config.dart';
import 'screens.dart';
import 'process_images.dart' as process_images;
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

  final config = Config(configPath);
  // validate config file
  await config.validate(screens);
  final Map configInfo = config.config;

  // init
  final stagingDir = configInfo['staging'];
  await Directory(stagingDir + '/test').create(recursive: true);
  await resources.unpackScripts(stagingDir);
  await fastlane.clearFastlaneDirs(configInfo, screens);

  // run integration tests in each android emulator for each locale and
  // process screenshots
  if (configInfo['devices']['android'] != null) {
    for (final emulatorName in configInfo['devices']['android'].keys) {
      for (final locale in configInfo['locales']) {
        final highestAvdName = utils.getHighestAndroidDevice(emulatorName);
        final deviceId = utils.findAndroidDeviceId(highestAvdName);
        final booted = deviceId == null ? false : true;
        await emulator(emulatorName, true, deviceId, booted, stagingDir,
            highestAvdName, locale);

        // store env for later use by tests
        await config.storeEnv(config, screens, emulatorName, locale, 'android');

        for (final testPath in configInfo['tests']) {
          print(
              'Capturing screenshots with test app $testPath on emulator \'$emulatorName\' in locale $locale ...');

          await screenshots(deviceId, testPath, stagingDir);
          // process screenshots
          await process_images.process(
              screens, configInfo, DeviceType.android, emulatorName, locale);
        }
        await emulator(emulatorName, false, deviceId, booted, stagingDir);
      }
    }
  }

  // run integration tests in each ios simulator for each locale and
  // process screenshots
  if (configInfo['devices']['ios'] != null) {
    for (final simulatorName in configInfo['devices']['ios'].keys) {
      for (final locale in configInfo['locales']) {
        final simulatorInfo =
            utils.getHighestIosDevice(utils.getIosDevices(), simulatorName);
        simulator(simulatorName, true, simulatorInfo, stagingDir, locale);

        // store env for later use by tests
        await config.storeEnv(config, screens, simulatorName, locale, 'ios');

        for (final testPath in configInfo['tests']) {
          print(
              'Capturing screenshots with test app $testPath on simulator \'$simulatorName\' in locale $locale ...');
          await screenshots(simulatorInfo['udid'], testPath, stagingDir);
          // process screenshots
          await process_images.process(
              screens, configInfo, DeviceType.ios, simulatorName, locale);
        }
        simulator(simulatorName, false, simulatorInfo);
      }
    }
  }

  print('\n\nScreen images are available in:');
  print('  ios/fastlane/screenshots');
  print('  android/fastlane/metadata/android');
  print('for upload to both Apple and Google consoles.');
  print('\nFor uploading and other automation options see:');
  print('  https://pub.dartlang.org/packages/fledge');
  print('\nscreenshots completed successfully.');
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
Future<void> emulator(
    String name, bool start, String deviceId, bool booted, String stagingDir,
    [String avdName, String testLocale = "en-US"]) async {
  if (start) {
    print('Starting emulator \'$name\' in locale $testLocale ...');

    final envVars = Platform.environment;
    if (envVars['CI'] == 'true') {
      // testing on CI/CD requires starting emulator in a specific way
      final androidHome = envVars['ANDROID_HOME'];
      await utils.streamCmd(
          '$androidHome/emulator/emulator',
          [
            '-avd',
            avdName,
            '-no-audio',
            '-no-window',
            '-no-snapshot',
            '-gpu',
            'swiftshader',
          ],
          '.',
          ProcessStartMode.detached);
    } else {
      // testing locally, so start emulator in normal way
      if (!booted) {
        await utils.streamCmd('flutter', ['emulator', '--launch', avdName]);
      }
    }

    // wait for emulator to start
    await utils.streamCmd(
        '$stagingDir/resources/script/android-wait-for-emulator', [deviceId]);

    // change locale
    String emulatorLocale = utils.androidDeviceLocale(deviceId);
//    print('deviceLocale=$emulatorLocale, testLocale=$testLocale');
    if (emulatorLocale != testLocale) {
      print(
          'Changing locale from $emulatorLocale to $testLocale on \'$name\'...');
      if (utils.cmd('adb', ['root'], '.', true) ==
          'adbd cannot run as root in production builds\n') {
        stdout.write(
            'Warning: locale will not be changed. Running in locale \'$emulatorLocale\'.\n');
        stdout.write(
            'To change locale you must use a non-production emulator (one that does not depend on Play Store). See:\n');
        stdout.write(
            '    https://stackoverflow.com/questions/43923996/adb-root-is-not-working-on-emulator/45668555#45668555 for details.\n');
      }
      flutterDriverBugWarning();
      // adb shell "setprop persist.sys.locale fr-CA; setprop ctl.restart zygote"
      utils.cmd('adb', [
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
    // note: there should be enough time to allow the emulator to restart
    // while app is being compiled.

  } else {
    if (!booted) {
      print('Stopping emulator: \'$name\' ...');
      utils.cmd('adb', ['-s', deviceId, 'emu', 'kill']);
      // wait for emulator to stop
      await utils.streamCmd(
          '$stagingDir/resources/script/android-wait-for-emulator-to-stop',
          [deviceId]);
    }
  }
}

///
/// Start/stop simulator.
///
void simulator(String name, bool start, Map simulatorInfo,
    [String stagingDir, String testLocale = 'en-US']) {
  final udId = simulatorInfo['udid'];
  final state = simulatorInfo['state'];
//  print('simulatorInfo=$simulatorInfo');
  if (start) {
    if (state == 'Booted') {
      // for testing
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

      utils.streamCmd('$stagingDir/resources/script/simulator-controller',
          [name, 'locale', testLocale]);
    }
    utils.cmd('xcrun', ['simctl', 'boot', udId]);
  } else {
    if (state != 'Booted') {
      print('Stopping simulator: \'$name\' ...');
      utils.cmd('xcrun', ['simctl', 'shutdown', udId]);
    }
  }
}

void flutterDriverBugWarning() {
  stdout.write(
      '\nWarning: running tests in a non-default locale will cause test to hang due to a bug in Flutter Driver (not related to \'screenshots\'). Modify your screenshots.yaml to use only the default locale for your location. For details of bug see comment at https://github.com/flutter/flutter/issues/27785#issue-408955077. Give comment a thumbs-up to get it fixed!\n\n');
}
