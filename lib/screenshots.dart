import 'dart:async';
import 'dart:io';

import 'package:screenshots/config.dart';
import 'package:screenshots/screens.dart';
import 'package:screenshots/process_images.dart' as process_images;
import 'package:screenshots/resources.dart' as resources;
import 'package:screenshots/utils.dart' as utils;
import 'package:screenshots/fastlane.dart' as fastlane;

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
  final screens = await Screens();
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
  final isMultipleLocales = configInfo['locales'].length > 1;

  // run integration tests in each android emulator for each locale and
  // process screenshots
  if (configInfo['devices']['android'] != null) {
    for (final emulatorName in configInfo['devices']['android'].keys) {
      for (final locale in configInfo['locales']) {
        await emulator(
            emulatorName, true, stagingDir, locale, isMultipleLocales);

        // store env for later use by tests
        await config.storeEnv(config, screens, emulatorName, locale, 'android');

        for (final testPath in configInfo['tests']) {
          print(
              'Capturing screenshots with test app $testPath on emulator \'$emulatorName\' in locale $locale ...');
          await screenshots(testPath, stagingDir);
          // process screenshots
          await process_images.process(
              screens, configInfo, DeviceType.android, emulatorName, locale);
        }
        await emulator(emulatorName, false, stagingDir);
      }
    }
  }

  // run integration tests in each ios simulator for each locale and
  // process screenshots
  if (configInfo['devices']['ios'] != null) {
    for (final simulatorName in configInfo['devices']['ios'].keys) {
      for (final locale in configInfo['locales']) {
        simulator(simulatorName, true, stagingDir, locale, isMultipleLocales);

        // store env for later use by tests
        await config.storeEnv(config, screens, simulatorName, locale, 'ios');

        for (final testPath in configInfo['tests']) {
          print(
              'Capturing screenshots with test app $testPath on simulator \'$simulatorName\' in locale $locale ...');
          await screenshots(testPath, stagingDir);
          // process screenshots
          await process_images.process(
              screens, configInfo, DeviceType.ios, simulatorName, locale);
        }
        simulator(simulatorName, false);
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
void screenshots(String testPath, String stagingDir) async {
  // clear existing screenshots from staging area
  utils.clearDirectory('$stagingDir/test');
  // run the test
  await utils.streamCmd('flutter', ['drive', testPath]);
}

///
/// Start/stop emulator.
///
Future<void> emulator(String emulatorName, bool start,
    [String stagingDir,
    String locale = "en-US",
    bool isMultipleLocales = false]) async {
  final highestEmulator = utils.getHighestAndroidDevice(emulatorName);
  if (start) {
    print('Starting emulator \'$emulatorName\' in locale $locale ...');

    final envVars = Platform.environment;
    if (envVars['CI'] == 'true') {
      // testing on CI/CD requires starting emulator in a specific way
      final androidHome = envVars['ANDROID_HOME'];
      await utils.streamCmd(
          '$androidHome/emulator/emulator',
          [
            '-avd',
            highestEmulator,
            '-no-audio',
            '-no-window',
            '-no-snapshot',
            '-gpu',
            'swiftshader',
          ],
          ProcessStartMode.detached);
    } else {
      // testing locally, so start emulator in normal way
      await utils
          .streamCmd('flutter', ['emulator', '--launch', highestEmulator]);
    }

    // wait for emulator to start
    await utils.streamCmd(
        '$stagingDir/resources/script/android-wait-for-emulator', []);

    // change locale
    if (isMultipleLocales) {
      if (utils.cmd('adb', ['root'], '.', true) ==
          'adbd cannot run as root in production builds\n') {
        stdout.write(
            'Warning: locale has not been changed. Running in default locale.\n');
        stdout.write(
            'To change locale you must use a non-production emulator (one that does not depend on Play Store). See:\n');
        stdout.write(
            '    https://stackoverflow.com/questions/43923996/adb-root-is-not-working-on-emulator/45668555#45668555 for details.\n');
      } else {
//      adb shell "setprop persist.sys.locale fr-CA; setprop ctl.restart zygote"
        utils.cmd('adb', [
          'shell',
          'setprop',
          'persist.sys.locale',
          locale,
          ';',
          'setprop',
          'ctl.restart',
          'zygote'
        ]);
        // note: there should be enough time to allow the emulator to restart
        // while app is being compiled.
      }
    }
  } else {
    print('Stopping emulator: \'$emulatorName\' ...');
    utils.cmd('adb', ['emu', 'kill']);
    // wait for emulator to stop
    await utils.streamCmd(
        '$stagingDir/resources/script/android-wait-for-emulator-to-stop', []);
  }
}

///
/// Start/stop simulator.
///
void simulator(String name, bool start,
    [String stagingDir,
    String locale = 'en-US',
    bool isMultipleLocales = false]) async {
  final simulatorInfo = utils.getHighestIosDevice(utils.getIosDevices(), name);
  final udid = simulatorInfo['udid'];
  final state = simulatorInfo['state'];
//  print('simulatorInfo=$simulatorInfo');
  if (start) {
    if (state == 'Booted') {
      print('Restarting simulator \'$name\' in locale $locale ...');
      utils.cmd('xcrun', ['simctl', 'shutdown', udid]);
    } else {
      print('Starting simulator \'$name\' in locale $locale ...');
    }
    if (isMultipleLocales) {
      await utils.streamCmd('$stagingDir/resources/script/simulator-controller',
          [name, 'locale', locale]);
    }
    utils.cmd('xcrun', ['simctl', 'boot', udid]);
  } else {
    print('Stopping simulator: \'$name\' ...');
    if (state == 'Booted') utils.cmd('xcrun', ['simctl', 'shutdown', udid]);
  }
}
