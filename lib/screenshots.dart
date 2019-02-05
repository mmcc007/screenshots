import 'dart:io';

import 'package:screenshots/config.dart';
import 'package:screenshots/screens.dart';
import 'package:screenshots/process_images.dart' as processImages;
import 'package:screenshots/resources.dart' as resources;
import 'package:screenshots/utils.dart' as utils;

/// default config file name
const String kConfigFileName = 'screenshots.yaml';

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
///
Future<void> run([String configPath = kConfigFileName]) async {
  final _config = Config(configPath);
  // validate config file
  await _config.validate();

  final Map config = _config.config;
  final Map screens = await Screens().init();

  // init
  final stagingDir = config['staging'];
  await Directory(stagingDir + '/test').create(recursive: true);
  await resources.unpackScript(stagingDir);

  // run integration tests in each android emulator for each locale and
  // process screenshots
  if (config['devices']['android'] != null)
    for (final emulatorName in config['devices']['android']) {
      emulator(emulatorName, true);
      for (final locale in config['locales']) {
        for (final testPath in config['tests']) {
          print(
              'Capturing screenshots with test $testPath on emulator $emulatorName in locale $locale ...');
          screenshots(testPath, stagingDir);
          // process screenshots
//          print('Capturing screenshots from  test $testPath ...');
          await processImages.process(
              screens, config, DeviceType.android, emulatorName, locale);
        }
      }
      emulator(emulatorName, false, stagingDir);
    }

  // run integration tests in each ios simulator for each locale and
  // process screenshots
  if (config['devices']['ios'] != null)
    for (final simulatorName in config['devices']['ios']) {
      simulator(simulatorName, true);
      for (final locale in config['locales']) {
        for (final testPath in config['tests']) {
          print(
              'Capturing screenshots with test $testPath on simulator $simulatorName in locale $locale ...');
          screenshots(testPath, stagingDir);
          await processImages.process(
              screens, config, DeviceType.ios, simulatorName, locale);
        }
      }
      simulator(simulatorName, false);
    }
}

///
/// Run the screenshot integration test on current emulator or simulator.
///
/// Test is expected to generate a sequential number of screenshots.
///
/// Assumes the integration test captures the screen shots into a known directory using
/// provided [capture_screen.screenshot()].
///
void screenshots(String testPath, String stagingDir) {
  // clear existing screenshots from staging area
  utils.clearDirectory('$stagingDir/test');
  // run the test
  utils.cmd('flutter', ['drive', testPath]);
}

///
/// Start/stop emulator.
///
void emulator(String name, bool start,
    [String staging, String locale = "en-US"]) {
  // todo: set locale of emulator
  name = name.replaceAll(' ', '_');
  if (start) {
    print('Starting emulator: $name ...');
    utils.cmd('flutter', ['emulator', '--launch', name]);
    // Note: the 'flutter build' of the test should allow enough time for emulator to start
    // otherwise, wait for emulator to start
//    cmd('script/android-wait-for-emulator', []);
  } else {
    print('Stopping emulator: $name ...');
    utils.cmd('adb', ['emu', 'kill']);
    // wait for emulator to stop
    utils
        .cmd('$staging/resources/script/android-wait-for-emulator-to-stop', []);
  }
}

///
/// Start/stop simulator.
///
void simulator(String name, bool start, [String locale = 'en-US']) {
  // todo: set locale of simulator
  Map simulatorInfo = utils.simulators()[name];
//  print('simulatorInfo=$simulatorInfo');

  if (start) {
    print('Starting simulator: $name ...');
    // xcrun simctl boot A23897F7-11DF-4F22-82E6-8BEB741F1990
    if (simulatorInfo['status'] == 'Shutdown')
      utils.cmd('xcrun', ['simctl', 'boot', simulatorInfo['id']]);
  } else {
    print('Stopping simulator: $name ...');
    if (simulatorInfo['status'] == 'Booted')
      utils.cmd('xcrun', ['simctl', 'shutdown', simulatorInfo['id']]);
  }
}
