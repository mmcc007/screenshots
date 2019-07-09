import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';

import 'image_processor.dart';
import 'screens.dart';
import 'package:yaml/yaml.dart';
import 'utils.dart' as utils;

import 'globals.dart';

///
/// Config info used to process screenshots for android and ios.
///
class Config {
  final String configPath;
  final YamlNode _docYaml;
  Map _screenshotsEnv; // current screenshots env

  Config({String this.configPath = kConfigFileName})
      : _docYaml = loadYaml(File(configPath).readAsStringSync());

  /// Get configuration information for supported devices
  Map get configInfo => _docYaml.value;

  /// Current screenshots runtime environment
  /// (updated before start of each test)
  Future<Map> get screenshotsEnv async {
    if (_screenshotsEnv == null) await _retrieveEnv();
    return _screenshotsEnv;
  }

  File get _envStore {
    return File(configInfo['staging'] + '/' + kEnvFileName);
  }

  /// Records screenshots environment before start of each test
  /// (called by screenshots)
  @visibleForTesting
  Future<void> storeEnv(Screens screens, String emulatorName, String locale,
      String deviceType) async {
    // store env for later use by tests
    final screenProps = screens.screenProps(emulatorName);
    final screenSize = screenProps == null ? null : screenProps['size'];
    final currentEnv = {
      'screen_size': screenSize,
      'locale': locale,
      'device_name': emulatorName,
      'device_type': deviceType,
    };
    await _envStore.writeAsString(json.encode(currentEnv));
  }

  Future<void> _retrieveEnv() async {
    _screenshotsEnv = json.decode(await _envStore.readAsString());
  }

  /// Check emulators and simulators are installed, devices attached,
  /// matching screen is available and tests exist.
  @visibleForTesting
  Future<bool> validate(
      Screens screens, List allDevices, List allEmulators) async {
    final isDeviceAttached = (device) => device != null;
    final isEmulatorInstalled = (emulator) => emulator != null;

    if (configInfo['devices']['android'] != null) {
      final devices = utils.getAndroidDevices(allDevices);
      for (String deviceName in configInfo['devices']['android'].keys) {
        if (ImageProcessor.isFrameRequired(
            configInfo, DeviceType.android, deviceName)) {
          // check screen available for this device
          _checkScreenAvailable(screens, deviceName);
        }

        // check emulator installed
        if (!isDeviceAttached(utils.getDevice(devices, deviceName)) &&
            !isEmulatorInstalled(
                utils.findEmulator(allEmulators, deviceName))) {
          stderr.write('Error: no device attached or emulator installed for '
              'device \'$deviceName\' in $configPath.\n');
          generateConfigGuide(screens, allDevices);
          exit(1);
        }
      }
    }

    if (configInfo['devices']['ios'] != null) {
      final devices = utils.getIosDevices(allDevices);
      final Map simulators = utils.getIosSimulators();
      for (String deviceName in configInfo['devices']['ios'].keys) {
        if (ImageProcessor.isFrameRequired(
            configInfo, DeviceType.ios, deviceName)) {
          // check screen available for this device
          _checkScreenAvailable(screens, deviceName);
        }

        // check simulator installed
        if (!isDeviceAttached(utils.getDevice(devices, deviceName)) &&
            !_isSimulatorInstalled(simulators, deviceName)) {
          stderr.write('Error: no device attached or simulator installed for '
              'device \'$deviceName\' in $configPath.\n');
          generateConfigGuide(screens, allDevices);
          exit(1);
        }
      }
    }

    for (String test in configInfo['tests']) {
      if (!await File(test).exists()) {
        stderr.write('Missing test: $test from $configPath not found.\n');
        exit(1);
      }
    }

    //  Due to issue with locales, issue warning for multiple locales.
    //  https://github.com/flutter/flutter/issues/27785
    if (configInfo['locales'].length > 1) {
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

  /// Checks if a simulator is installed, matching the device named in config file.
  bool _isSimulatorInstalled(Map simulators, String deviceName) {
    // check simulator installed
    bool isSimulatorInstalled = false;
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

        isSimulatorInstalled = true;
      }
    });
    return isSimulatorInstalled;
  }

  /// Generate a guide for configuring Screenshots in current environment.
  @visibleForTesting
  void generateConfigGuide(Screens screens, List devices) {
    stdout.write('\nGuide:');
    _reportAttachedDevices(devices);
    _reportInstalledEmulators(utils.getAvdNames());
    _reportInstalledSimulators(utils.getIosSimulators());
    _reportSupportedDevices(screens);
    stdout.write(
        '\n  Each device listed in screenshots.yaml with framing required must'
        '\n    1. have a supported screen'
        '\n    2. have an attached device or an installed emulator/simulator.\n\n');
  }

  // check screen is available for device
  void _checkScreenAvailable(Screens screens, String deviceName) {
    if (screens.screenProps(deviceName) == null) {
      stderr.write(
          'Error: screen not available for device \'$deviceName\' in $configPath.\n');
      stderr.flush();
      stdout.write(
          '\n  Use a supported device or set \'frame: false\' for device in $configPath.\n\n'
          '  If framing for device is required, request screen support by\n'
          '  creating an issue in:\n'
          '  https://github.com/mmcc007/screenshots/issues.\n\n');
      _reportSupportedDevices(screens);
      exit(1);
    }
  }

  void _reportSupportedDevices(Screens screens) {
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

  void _reportAttachedDevices(List devices) {
    stdout.write('\n  Attached devices:\n');
    for (final device in devices) {
      if (device['emulator'] == false) {
        device['platform'] == 'ios'
            ? stdout.write('    ${device['model']}\n')
            : stdout.write('    ${device['name']}\n');
      }
    }
  }

  void _reportInstalledEmulators(List emulators) {
    stdout.write('\n  Installed emulators:\n');
    for (final emulator in emulators) {
      stdout.write('    $emulator\n');
    }
  }

  void _reportInstalledSimulators(Map simulators) {
    stdout.write('  Installed simulators:\n');
    simulators.forEach((simulator, _) => stdout.write('    $simulator\n'));
  }
}
