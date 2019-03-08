import 'dart:async';
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
  Future<bool> validate(Screens screens) async {
    if (config['devices']['android'] != null) {
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
          stderr.write('configuration error: emulator not installed for '
              'device \'$device\' in $configPath.\n');
          stdout.write('\nInstall the missing emulator or use a supported '
              'device with an installed emulator in $configPath.\n');
          configGuide(screens);
          exit(1);
        }
      }
    }

    if (config['devices']['ios'] != null) {
      // check simulators
      final Map simulators = utils.getIosDevices();
      for (String device in config['devices']['ios']) {
        // check screen available for this device
        screenAvailable(screens, device);

        // check simulator installed
        bool simulatorInstalled = false;
        simulators.forEach((simulator, os) {
//          print('device=$device, simulator=$simulator');
          if (simulator == device) {
            // check for duplicate installs
//            print('os=$os');

            final osName = os.keys.first;
            final osDevice = os[osName][0]['udid'];
            // check for device present with multiple os's
            // or with duplicate name
            if (os.length > 1 || os[osName].length > 1) {
              print('Warning: multiple versions of \'$device\' detected.');
              print('  Using \'$device\' with iOS: $osName, ID: $osDevice.');
            }

            simulatorInstalled = true;
          }
        });
        if (!simulatorInstalled) {
          stderr.write('configuration error: simulator not installed for '
              'device \'$device\' in $configPath.\n');
          stdout.write('\nInstall the missing simulator or use a supported '
              'device with an installed simulator in $configPath.\n');
          configGuide(screens);
          exit(1);
        }
      }
    }

    for (String test in config['tests']) {
      if (!await File(test).exists()) {
        stderr.write('Missing test: $test from $configPath not found.\n');
        exit(1);
      }
    }

    //  Due to issue with locales, issue warning for multiple locales.
    //  https://github.com/flutter/flutter/issues/27785
    if (config['locales'].length > 1) {
      stdout.write('Warning: Flutter integration tests do not work in '
          'multiple locals.\n');
      stdout.write('  See comment on issue:\n'
          '  https://github.com/flutter/flutter/issues/27785#issue-408955077\n'
          '  for details.\n'
          '  and provide a thumbs-up on the comment to prioritize a fix for this issue!\n\n'
          '  In the meantime, while waiting for a fix, only use the default locale\n'
          '  in screenshots.yaml\n\n');
    }

    return true;
  }

  void configGuide(Screens screens) {
    installedEmulators(utils.emulators());
    installedSimulators(utils.getIosDevices());
    supportedDevices(screens);
    stdout.write(
        '\nEach device listed in screenshots.yaml must have a corresponding '
        'screen and emulator/simulator.\n');
  }

  // check screen is available for device
  void screenAvailable(Screens screens, String deviceName) {
    if (screens.screenProps(deviceName) == null) {
      stderr.write(
          'configuration error: screen not available for device \'$deviceName\' in $configPath.\n');
      stdout.write('\n  Use a supported device in $configPath.\n\n'
          '  If device is required, request screen support for device by\n'
          '  creating an issue in:\n'
          '  https://github.com/mmcc007/screenshots/issues.\n\n');
      supportedDevices(screens);

//      stderr.flush();
      exit(1);
    }
  }

  void supportedDevices(Screens screens) {
    stdout.write('\n  Currently supported devices:\n');
    screens.screens.forEach((os, v) {
      stdout.write('    $os:\n');
      v.value.forEach((screenNum, screenProps) {
        for (String device in screenProps['devices']) {
          stdout.write('      $device\n');
        }
      });
    });
  }

  void installedEmulators(List emulators) {
    stdout.write('\n  Installed emulators:\n');
    for (final emulator in emulators) {
      stdout.write('    $emulator\n');
    }
  }

  void installedSimulators(Map simulators) {
    stdout.write('  Installed simulators:\n');
    simulators.forEach((simulator, _) => stdout.write('    $simulator\n'));
  }
}
