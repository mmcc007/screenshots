import 'package:meta/meta.dart';
import 'package:screenshots/src/daemon_client.dart';
import 'package:tool_base/tool_base.dart' hide Config;

import 'config.dart';
import 'globals.dart';
import 'screens.dart';
import 'utils.dart' as utils;

/// Check emulators and simulators are installed, devices attached,
/// matching screen is available and tests exist.
Future<bool> isValidConfig(
    Config config, Screens screens, List allDevices, List allEmulators) async {
  bool isValid = true;
  bool showDeviceGuide = false;
  final configPath = config.configPath;

  // validate tests
  for (String test in config.tests) {
    if (!isValidTestPaths(test)) {
      printError('Invalid config: \'$test\' in $configPath');
      isValid = false;
    }
  }

  final isDeviceAttached = (device) => device != null;

  // validate android device
  if (config.isRunTypeActive(DeviceType.android)) {
    final androidDevices = utils.getAndroidDevices(allDevices);
    for (ConfigDevice configDevice in config.androidDevices) {
      if (config.isFrameRequired(configDevice.name, null)) {
        // check screen available for this device
        if (!_isScreenAvailable(screens, configDevice.name, configPath)) {
          isValid = false;
        }
      }

      // check device attached or emulator running or emulator installed
      if (!isDeviceAttached(
              utils.getDevice(androidDevices, configDevice.name)) &&
          !isEmulatorInstalled(allEmulators, configDevice.name)) {
        printError('No device attached or emulator installed for '
            'device \'${configDevice.name}\' in $configPath.');
        printError('  Either remove \'${configDevice.name}\' from $configPath or '
            'attach/install the matching device/emulator');
        isValid = false;
        showDeviceGuide = true;
      }
    }
  }

  // validate macOS
  if (platform.isMacOS) {
    // validate ios device
    if (config.isRunTypeActive(DeviceType.ios)) {
      final iosDevices = utils.getIosDaemonDevices(allDevices);
      final Map simulators = utils.getIosSimulators();
      for (ConfigDevice configDevice in config.iosDevices) {
        if (config.isFrameRequired(configDevice.name, null)) {
          // check screen available for this device
          if (!_isScreenAvailable(screens, configDevice.name, configPath)) {
            isValid = false;
          }
        }

        // check device attached or simulator installed
        if (!isDeviceAttached(utils.getDevice(iosDevices, configDevice.name)) &&
            !isSimulatorInstalled(simulators, configDevice.name)) {
          printError('No device attached or simulator installed for '
              'device \'${configDevice.name}\' in $configPath.');
          printError('  Either remove \'${configDevice.name}\' from $configPath or '
              'attach/install the matching device/simulator');
          showDeviceGuide = true;
          isValid = false;
        }
      }
    }
  } else {
    // if not macOS
    if (config.isRunTypeActive(DeviceType.ios)) {
      printError(
          'An iOS run cannot be configured on a non-macOS platform. Please modify $configPath');
      isValid = false;
    }
  }

  // validate device params
  final deviceNames = config.deviceNames;
  for (final devName in deviceNames) {
    final configDevice = config.getDevice(devName);
    if (configDevice != null) {
      final frame = configDevice.isFramed;
      if (frame != null && !isValidFrame(frame)) {
        printError(
            'Invalid value for \'frame\' for device \'$devName\': $frame');
        printStatus('Valid values:');
        printStatus('  true');
        printStatus('  false');
        isValid = false;
      }
    }
  }
  if (showDeviceGuide) {
    deviceGuide(screens, allDevices, allEmulators, configPath);
  }
  return isValid;
}

/// Checks all paths are valid.
/// Note: does not cover all uses cases.
bool isValidTestPaths(String driverArgs) {
  final driverPathRegExp = RegExp(r'--driver[= ]+([^\s]+)');
  final targetPathRegExp = RegExp(r'--target[= ]+([^\s]+)');
  final regExps = [driverPathRegExp, targetPathRegExp];

  bool pathExists(String path) {
    if (!fs.file(path).existsSync()) {
      printError('File \'$path\' not found.');
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
@visibleForTesting
bool isSimulatorInstalled(Map simulators, String deviceName) {
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

/// Generate a guide for matching configured devices to current environment.
void deviceGuide(Screens screens, List<DaemonDevice> devices,
    List<DaemonEmulator> emulators, String configPath) {
  printStatus('\nDevice Guide:');
  if (devices != null && devices.isNotEmpty) {
    printStatus('\n  Attached devices/running emulators:');
    _printAttachedDevices(devices);
  }
  if (emulators != null && emulators.isNotEmpty) {
    printStatus('\n  Installed emulators:');
    _printEmulators(emulators, 'android');
  }
  if (platform.isMacOS) {
    _printSimulators();
  }
//  _reportSupportedDevices(screens);
//  printStatus('\n  Each device listed in $configPath must'
//      '\n    1. have a supported screen'
//      '\n    2. have an attached device or an installed emulator/simulator.'
//      '\n  To bypass requirement #1 add \'frame: false\' parameter after device\'s name in $configPath.');
}

// check screen is available for device
bool _isScreenAvailable(Screens screens, String deviceName, String configPath) {
  final screenProps = screens.getScreen(deviceName);
  if (screenProps == null || Screens.isAndroidModelTypeScreen(screenProps)) {
    printError(
        'Screen not available for device \'$deviceName\' in $configPath.');
    printError(
        '\n  Use a device with a supported screen or set \'frame: false\' for'
        '\n  device in $configPath.');
    screenGuide(screens);
    printStatus(
        '\n  If framing for device is required, request screen support by'
        '\n  creating an issue in:'
        '\n  https://github.com/mmcc007/screenshots/issues.');

    return false;
  }
  return true;
}

void screenGuide(Screens screens) {
  printStatus('\nScreen Guide:');
  printStatus('\n  Supported screens:');
  for (final os in ['android', 'ios']) {
    printStatus('    $os:');
    for (String deviceName in screens.getSupportedDeviceNamesByOs(os)) {
      printStatus(
          '      $deviceName (${screens.getScreen(deviceName)['size']})');
    }
  }
}

void _printAttachedDevices(List<DaemonDevice> devices) {
  for (final device in devices) {
//    if (device.emulator == false) {
      device.platform == 'ios'
          ? printStatus('    ${device.iosModel} (${device.id})')
          : printStatus('    ${device.emulator?'${device.emulatorId}':'${device.name}'} (${device.id})');
//    }
  }
}

void _printEmulators(List<DaemonEmulator> emulators, String platformType) {
  emulators
      .where((emulator) => emulator.platformType == platformType)
      .forEach((emulator) => printStatus('    ${emulator.id}'));
}

void _printSimulators() {
  final simulatorNames = utils.getIosSimulators().keys.toList();
  simulatorNames.sort((thisSim, otherSim) =>
      '$thisSim'.contains('iPhone') && !'$otherSim'.contains('iPhone')
          ? -1
          : thisSim.compareTo(otherSim));
  if (simulatorNames.isNotEmpty) {
    printStatus('\n  Installed simulators:');
    simulatorNames.forEach((simulatorName) =>
        printStatus('    $simulatorName'));
  }
}

bool isValidFrame(dynamic frame) {
  return frame != null && (frame == true || frame == false);
}
