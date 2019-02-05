import 'dart:io';

import 'package:screenshots/screens.dart';
import 'package:screenshots/screenshots.dart';
import 'package:yaml/yaml.dart';
import 'package:screenshots/utils.dart' as utils;

///
/// Config info used to process screenshots for android and ios.
///
class Config {
  final String configPath;
  YamlNode docYaml;

  Config([this.configPath = kConfigFileName]) {
    docYaml = loadYaml(File(configPath).readAsStringSync());
  }

  /// Get configuration information for supported devices
  Map get config => docYaml.value;

  /// Check emulators and simulators are installed,
  /// matching screen is available and tests exist.
  Future<bool> validate() async {
    final Map screens = await Screens().init();

    // check emulators
    final List emulators = utils.emulators();
    for (String device in config['devices']['android']) {
      // check screen available for this device
      screenAvailable(screens, device);

      // check emulator installed
      bool emulatorInstalled = false;
      for (String emulator in emulators) {
        if (emulator.contains(device.replaceAll(' ', '_')))
          emulatorInstalled = true;
      }
      if (!emulatorInstalled) {
        stderr.write(
            'configuration error: emulator not installed for device \'$device\' in $configPath.\n');
        stdout.write(
            'missing emulator: install the missing emulator or use a device '
            'with an existing emulator in $configPath.\n');
        exit(1);
      }
    }

    // check simulators
    final Map simulators = utils.simulators();
    for (String device in config['devices']['ios']) {
      // check screen available for this device
      screenAvailable(screens, device);

      // check simulator installed
      bool simulatorInstalled = false;
      simulators.forEach((simulator, _) {
//        print('simulator=$simulator, device=$device');
        if (simulator == device) simulatorInstalled = true;
      });
      if (!simulatorInstalled) {
        stderr.write(
            'configuration error: simulator not installed for device \'$device\' in $configPath.\n');
        stdout.write(
            'missing simulator: install the missing simulator or use an existing '
            'simulator for device in $configPath.\n');
        exit(1);
      }
    }

    for (String test in config['tests']) {
      if (!await File(test).exists()) {
        stderr.write('Missing test: $test from $configPath not found.\n');
        exit(1);
      }
    }

    return true;
  }

  // check screen is available for device
  void screenAvailable(Map screens, String deviceName) {
    if (Screens().screenProps(screens, deviceName) == null) {
      stderr.write(
          'configuration error: screen not found for device \'$deviceName\' in $configPath.\n');
      stdout.write(
          'unsupported device: use a supported device in $configPath. If device '
          'is required, request screen support by creating an issue in '
          'https://github.com/mmcc007/screenshots/issues.\n');
      stdout.write('currently supported devices:\n');
      (screens as YamlNode).value.forEach((os, v) {
        stdout.write('    $os:\n');
        v.value.forEach((screenNum, screenProps) {
          for (String device in screenProps['devices']) {
            stdout.write('        $device\n');
          }
        });
      });

//      stderr.flush();
      exit(1);
    }
  }
}
