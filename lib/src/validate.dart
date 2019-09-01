import 'dart:io';

import 'package:screenshots/src/daemon_client.dart';

import 'base/platform.dart';
import 'config.dart';
import 'globals.dart';
import 'orientation.dart';
import 'screens.dart';
import 'utils.dart' as utils;

/// Check emulators and simulators are installed, devices attached,
/// matching screen is available and tests exist.
Future<bool> validate(
    Config config, Screens screens, List allDevices, List allEmulators) async {
  final configPath = config.configPath;
  // validate params
  final deviceNames = config.deviceNames;
  for (final devName in deviceNames) {
    final configDevice = config.getDevice(devName);
    if (configDevice != null) {
      if (configDevice.orientationStr != null &&
          !isValidOrientation(configDevice.orientationStr)) {
        printError(
            'Invalid value for \'orientation\' for device \'$devName\': $configDevice.orientationStr');
        printStatus('Valid values:');
        for (final orientation in Orientation.values) {
          printStatus('  ${utils.getStringFromEnum(orientation)}');
        }
        exit(1);
      }
      final frame = configDevice.isFramed;
      if (frame != null && !isValidFrame(frame)) {
        printError(
            'Invalid value for \'frame\' for device \'$devName\': $frame');
        printStatus('Valid values:');
        printStatus('  true');
        printStatus('  false');
        exit(1);
      }
    }
  }

  final isDeviceAttached = (device) => device != null;

  if (config.isRunTypeActive(DeviceType.android)) {
    final androidDevices = utils.getAndroidDevices(allDevices);
    for (ConfigDevice configDevice in config.androidDevices) {
      if (config.isFrameRequired(configDevice.name)) {
        // check screen available for this device
        _checkScreenAvailable(screens, configDevice.name, configPath);
      }

      // check emulator installed
      if (!isDeviceAttached(
              utils.getDevice(androidDevices, configDevice.name)) &&
          !isEmulatorInstalled(allEmulators, configDevice.name)) {
        printError('No device attached or emulator installed for '
            'device \'$configDevice.name\' in $configPath.\n');
        generateConfigGuide(screens, allDevices, configPath);
        exit(1);
      }
    }
  }

  if (config.isRunTypeActive(DeviceType.ios)) {
    final iosDevices = utils.getIosDevices(allDevices);
    final Map simulators = utils.getIosSimulators();
    for (ConfigDevice configDevice in config.iosDevices) {
      if (config.isFrameRequired(configDevice.name)) {
        // check screen available for this device
        _checkScreenAvailable(screens, configDevice.name, configPath);
      }

      // check simulator installed
      if (!isDeviceAttached(utils.getDevice(iosDevices, configDevice.name)) &&
          !_isSimulatorInstalled(simulators, configDevice.name)) {
        printError('No device attached or simulator installed for '
            'device \'${configDevice.name}\' in $configPath.');
        generateConfigGuide(screens, allDevices, configPath);
        exit(1);
      }
    }
  }

  for (String test in config.tests) {
    if (!isValidTestPaths(test)) {
      printError('Invalid config: $test in $configPath');
      exit(1);
    }
  }

  return true;
}

/// Checks all paths are valid.
/// Note: does not cover all uses cases.
bool isValidTestPaths(String driverArgs) {
  final driverPathRegExp = RegExp(r'--driver[= ]+([^\s]+)');
  final targetPathRegExp = RegExp(r'--target[= ]+([^\s]+)');
  final regExps = [driverPathRegExp, targetPathRegExp];

  bool pathExists(String path) {
    if (!File(path).existsSync()) {
      printError('File \'$path\' for test config \'$driverArgs\' not found.\n');
      return false;
    }
    return true;
  }

  // Remember any failed path during matching (if any matching)
  bool isInvalidPath = false;
  bool matchFound = false;
  for (final regExp in regExps) {
    final match = regExp.firstMatch(driverArgs);
    if (match != null) {
      matchFound = true;
      final path = match.group(1);
      isInvalidPath = isInvalidPath || !pathExists(path);
    }
  }

  // if invalid path found during matching return, otherwise check default path
  return !(isInvalidPath
      ? isInvalidPath
      : matchFound ? isInvalidPath : !pathExists(driverArgs));
}

/// Check if an emulator is installed.
bool isEmulatorInstalled(List<DaemonEmulator> emulators, String deviceName) {
  final emulator = utils.findEmulator(emulators, deviceName);
  final isEmulatorInstalled = emulator != null;

  // check for device installed with multiple avd versions
  if (isEmulatorInstalled) {
    final matchingEmulators =
        emulators.where((emulator) => emulator.name == deviceName);
    if (matchingEmulators != null && matchingEmulators.length > 1) {
      printStatus('Warning: \'$deviceName\' has multiple avd versions.');
      printStatus(
          '       : Using \'$deviceName\' with avd version ${emulator.id}.');
    }
  }
  return isEmulatorInstalled;
}

/// Checks if a simulator is installed, matching the device named in config file.
bool _isSimulatorInstalled(Map simulators, String deviceName) {
  // check simulator installed
  bool isSimulatorInstalled = false;
  simulators.forEach((simulatorName, iOSVersions) {
    if (simulatorName == deviceName) {
      // check for duplicate installs
      final iOSVersionName = utils.getHighestIosVersion(iOSVersions);
      final udid = iOSVersions[iOSVersionName][0]['udid'];
      // check for device present with multiple os's
      // or with duplicate name
      if (iOSVersions.length > 1 || iOSVersions[iOSVersionName].length > 1) {
        printStatus('Warning: \'$deviceName\' has multiple iOS versions.');
        printStatus(
            '       : Using \'$deviceName\' with iOS version $iOSVersionName (ID: $udid).');
      }

      isSimulatorInstalled = true;
    }
  });
  return isSimulatorInstalled;
}

/// Generate a guide for configuring Screenshots in current environment.
void generateConfigGuide(
    Screens screens, List<DaemonDevice> devices, String configPath) {
  printStatus('\nGuide:');
  _reportAttachedDevices(devices);
  _reportInstalledEmulators(utils.getAvdNames());
  if (platform.isMacOS) _reportInstalledSimulators(utils.getIosSimulators());
  _reportSupportedDevices(screens);
  printStatus('\n  Each device listed in $configPath with framing required must'
      '\n    1. have a supported screen'
      '\n    2. have an attached device or an installed emulator/simulator.'
      '\n  To bypass requirement #1 add \'frame: false\' after device in $configPath');
}

// check screen is available for device
void _checkScreenAvailable(
    Screens screens, String deviceName, String configPath) {
  final screenProps = screens.getScreen(deviceName);
  if (screenProps == null || _isAndroidModelTypeScreen(screenProps)) {
    printError(
        'Screen not available for device \'$deviceName\' in $configPath.');
    printStatus(
        '\n  Use a supported device or set \'frame: false\' for device in $configPath.\n\n'
        '  If framing for device is required, request screen support by\n'
        '  creating an issue in:\n'
        '  https://github.com/mmcc007/screenshots/issues.');
    _reportSupportedDevices(screens);
    exit(1);
  }
}

void _reportSupportedDevices(Screens screens) {
  printStatus('\n  Devices with supported screens:');
  screens.screens.forEach((os, v) {
    // omit ios devices if not on mac
    if (!(!platform.isMacOS && os == 'ios')) {
      printStatus('    $os:');
      v.forEach((screenId, screenProps) {
        // omit devices that have screens that are
        // only used to identify android model type
        if (!_isAndroidModelTypeScreen(screenProps)) {
          for (String device in screenProps['devices']) {
            printStatus('      $device');
          }
        }
      });
    }
  });
}

/// Test for screen used for identifying android model type
bool _isAndroidModelTypeScreen(screenProps) => screenProps['size'] == null;

void _reportAttachedDevices(List<DaemonDevice> devices) {
  printStatus('\n  Attached devices:');
  for (final device in devices) {
    if (device.emulator == false) {
      device.platform == 'ios'
          ? printStatus('    ${device.iosModel}')
          : printStatus('    ${device.name}');
    }
  }
}

void _reportInstalledEmulators(List emulators) {
  printStatus('\n  Installed emulators:');
  for (final emulator in emulators) {
    printStatus('    $emulator');
  }
}

void _reportInstalledSimulators(Map simulators) {
  printStatus('  Installed simulators:');
  simulators.forEach((simulator, _) => printStatus('    $simulator'));
}

bool isValidOrientation(String orientation) {
  return Orientation.values.firstWhere(
          (o) => utils.getStringFromEnum(o) == orientation,
          orElse: () => null) !=
      null;
}

bool isValidFrame(dynamic frame) {
  return frame != null && (frame == true || frame == false);
}
