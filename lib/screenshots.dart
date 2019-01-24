import 'dart:io';

import 'package:screenshots/config.dart';
import 'package:screenshots/devices.dart';
import 'package:screenshots/process_images.dart' as processImages;
import 'package:screenshots/resources.dart' as resources;
import 'package:screenshots/utils.dart' as utils;
//import 'package:yaml/yaml.dart';

/// Distinguish device OS.
enum DeviceType { android, ios }

/// Capture screenshots, process, and load into fastlane according to config file.
///
/// For each emulator/simulator, locale and integration test:
///
/// 1. Start the emulator/simulator for current locale.
/// 2. Run the integration test and capture the screenshots.
/// 3. Process the screenshots including adding a frame if required.
/// 4. Move processed screenshots to fastlane destination for upload to stores.
///
void run(String configPath) async {
  final config = Config(configPath).config;
  final Map devices = await Devices().init();

  // init
  final stagingDir = config['staging'];
  await Directory(stagingDir + '/test').create(recursive: true);
  await resources.unpackScript(stagingDir);
//  print('config=$config');

  // run integration test in each android emulator for each locale and
  // process screenshots
  for (final _emulator in config['devices']['android']) {
//    print('emulator=$_emulator');
    emulator(_emulator, true);
    for (final locale in config['locales']) {
      print('locale=$locale');
      for (final testPath in config['tests']) {
        print(
            'capturing screenshots with test $testPath on emulator $_emulator at locale $locale ...');
        screenshots(testPath, stagingDir, 'android');
        // process screenshots
        print('capturing screenshots from  test $testPath ...');
        await processImages.process(
            devices, config, DeviceType.android, _emulator, locale);
      }
    }
    emulator(_emulator, false, stagingDir);
  }

  // run integration test in each ios simulator for each locale and
  // process screenshots
  for (final simulatorName in config['devices']['ios']) {
    print('simulator=$simulatorName');
    simulator(simulatorName, true);
    for (final locale in config['locales']) {
      print('locale=$locale');
//      simulator(_simulator, true);
      for (final testPath in config['tests']) {
        print('testPath=$testPath');
        screenshots(testPath, stagingDir, 'ios');
        await processImages.process(
            devices, config, DeviceType.ios, simulatorName, locale);
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
void screenshots(String testPath, String stagingDir, String os,
    [String locale = "en-US"]) {
  // clear existing screenshots from staging area
  final screensDir = '$stagingDir/test';
  utils.clearDirectory(screensDir);
  // run the test
  utils.cmd('flutter', ['drive', testPath]);
  // move screenshots to the os's directory under a known directory
//  final osDir = '$stagingDir/$os/$locale';
//  _clearDirectory(osDir);
//  _moveDirectory(screensDir, osDir);
}

///
/// Start/stop emulator.
///
void emulator(String name, bool start,
    [String staging, String locale = "en-US"]) {
  // todo: set locale of emulator
  name = name.replaceAll(' ', '_');
  if (start) {
    utils.cmd('flutter', ['emulator', '--launch', name]);
//    cmd('script/android-wait-for-emulator', []);
  } else {
    utils.cmd('adb', ['emu', 'kill']);
    utils
        .cmd('$staging/resources/script/android-wait-for-emulator-to-stop', []);
  }
}

///
/// Start/stop simulator.
///
void simulator(String name, bool start, [String locale = 'en-US']) {
  // todo: set name and locale of simulator
  Map simulatorInfo = utils.simulators()[name];
  print('simulatorInfo=$simulatorInfo');

  if (start) {
    print('start $name');
//    xcrun simctl boot A23897F7-11DF-4F22-82E6-8BEB741F1990
//    utils.cmd('flutter emulator', ['--launch', name]);
    if (simulatorInfo['status'] == 'Shutdown')
      utils.cmd('xcrun', ['simctl', 'boot', simulatorInfo['id']]);
  } else {
    print('stop $name');
    if (simulatorInfo['status'] == 'Booted')
      utils.cmd('xcrun', ['simctl', 'shutdown', simulatorInfo['id']]);

//    xcrun simctl shutdown A23897F7-11DF-4F22-82E6-8BEB741F1990
//  `killall 'iOS Simulator' &> /dev/null`
//  `killall Simulator &> /dev/null`
//    utils.cmd('killall', ['Simulator']);
  }
}
