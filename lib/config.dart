import 'dart:async';
import 'dart:convert';
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
  Map _screenshotsEnv; // current screenshots env

  Config([this.configPath = kConfigFileName]) {
    docYaml = loadYaml(File(configPath).readAsStringSync());
  }

  /// Get configuration information for supported devices
  Map get config => docYaml.value;

  /// Current screenshots runtime environment
  /// (updated before start of each test)
  Map get screenshotsEnv => _screenshotsEnv;

  File get _envStore {
    return File(config['staging'] + '/' + kEnvFileName);
  }

  /// Records screenshots environment before start of each test
  /// (called by screenshots)
  Future<void> storeEnv(
      Config config, Screens screens, emulatorName, locale, deviceType) async {
    // store env for later use by tests
    final currentEnv = {
      'screen_size': screens.screenProps(emulatorName)['size'],
      'locale': locale,
      'device_name': emulatorName,
      'device_type': deviceType,
    };
    await _envStore.writeAsString(json.encode(currentEnv));
  }

  /// Retrieves screenshots environment at start of each test
  /// (called by test)
  Future<void> retrieveEnv() async {
    _screenshotsEnv = json.decode(await _envStore.readAsString());
  }

  /// Check emulators and simulators are installed,
  /// matching screen is available and tests exist.
  Future<bool> validate(Screens screens) async {
    if (config['devices']['android'] != null) {
      // check emulators
      final List emulators = utils.getAvdNames();
      for (String device in config['devices']['android'].keys) {
        // check screen available for this device
        screenAvailable(screens, device);

        // check emulator installed
        if (!isEmulatorInstalled(emulators, device)) {
          stderr.write('Error: emulator not installed for '
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
      for (String deviceName in config['devices']['ios'].keys) {
        // check screen available for this device
        screenAvailable(screens, deviceName);

        // check simulator installed
        bool simulatorInstalled = isSimulatorInstalled(simulators, deviceName);
        if (!simulatorInstalled) {
          stderr.write('Error: simulator not installed for '
              'device \'$deviceName\' in $configPath.\n');
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
          '  for your location in screenshots.yaml\n\n');
    }

    return true;
  }

  /// Checks if an emulator is installed, matching the device named in config file.
  bool isEmulatorInstalled(List emulatorNames, String deviceName) {
    // check emulator installed
    bool emulatorInstalled = false;
    final deviceNameNormalized = deviceName.replaceAll(' ', '_');
    for (String emulatorName in emulatorNames) {
      if (emulatorName.contains(deviceNameNormalized)) {
        final highestEmulatorName = utils.getHighestAVD(deviceName);
        if (highestEmulatorName != deviceNameNormalized && !emulatorInstalled) {
          print('Warning: \'$deviceName\' does not have a matching emulator.');
          print('       : Using \'$highestEmulatorName\'.');
        }
        emulatorInstalled = true;
      }
    }
    return emulatorInstalled;
  }

  /// Checks if a simulator is installed, matching the device named in config file.
  bool isSimulatorInstalled(Map simulators, String deviceName) {
    // check simulator installed
    bool simulatorInstalled = false;
    simulators.forEach((simulatorName, iOSVersions) {
      //          print('device=$device, simulator=$simulator');
      if (simulatorName == deviceName) {
        // check for duplicate installs
        //            print('os=$os');

        final iOSVersionName = utils.getHighestIosVersion(iOSVersions);
        final udid = iOSVersions[iOSVersionName][0]['udid'];
        // check for device present with multiple os's
        // or with duplicate name
        if (iOSVersions.length > 1 || iOSVersions[iOSVersionName].length > 1) {
          print('Warning: \'$deviceName\' has multiple iOS versions.');
          print(
              '       : Using \'$deviceName\' with iOS version $iOSVersionName (ID: $udid).');
        }

        simulatorInstalled = true;
      }
    });
    return simulatorInstalled;
  }

  void configGuide(Screens screens) {
    stdout.write('\nGuide:');
    installedEmulators(utils.getAvdNames());
    installedSimulators(utils.getIosDevices());
    supportedDevices(screens);
    stdout.write(
        '\n  Each device listed in screenshots.yaml must have a supported '
        'screen and emulator/simulator.\n');
  }

  // check screen is available for device
  void screenAvailable(Screens screens, String deviceName) {
    if (screens.screenProps(deviceName) == null) {
      stderr.write(
          'Error: screen not available for device \'$deviceName\' in $configPath.\n');
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
    stdout.write('\n  Devices with supported screens:\n');
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
