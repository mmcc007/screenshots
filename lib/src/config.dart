import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:screenshots/src/orientation.dart';

import 'globals.dart';
import 'screens.dart';
import 'utils.dart' as utils;

const kEnvConfigPath = 'SCREENSHOTS_YAML';

/// Config info used to manage screenshots for android and ios.
// Note: should not have context dependencies as is also used in driver.
// todo: yaml validation
class Config {
  Config({this.configPath = kConfigFileName, String configStr}) {
    if (configStr != null) {
      // used by tests
      _configInfo = utils.parseYamlStr(configStr);
    } else {
      if (isScreenShotsAvailable) {
        final envConfigPath = io.Platform.environment[kEnvConfigPath];
        if (envConfigPath == null) {
          // used by command line and by driver if using kConfigFileName
          _configInfo = utils.parseYamlFile(configPath);
        } else {
          // used by driver
          _configInfo = utils.parseYamlFile(envConfigPath);
        }
      } else {
        io.stdout.writeln('Warning: screenshots not available.\n'
            '\tTo enable set $kEnvConfigPath environment variable\n'
            '\tor create $kConfigFileName.');
      }
    }
  }

  /// Checks if screenshots is available.
  ///
  /// Created for use in driver.
  // Note: order of boolean tests is important
  bool get isScreenShotsAvailable =>
      io.Platform.environment[kEnvConfigPath] != null ||
      io.File(configPath).existsSync();

  final String configPath;

  Map _configInfo;
  Map _screenshotsEnv; // current screenshots env
  List<ConfigDevice> _devices;

  // Getters
  List<String> get tests => _processList(_configInfo['tests']);

  String get stagingDir => _configInfo['staging'];

  List<String> get locales => _processList(_configInfo['locales']);

  List<ConfigDevice> get devices => _devices ??=
      _processDevices(_configInfo['devices'], isFrameEnabled);

  List<ConfigDevice> get iosDevices =>
      devices.where((device) => device.deviceType == DeviceType.ios).toList();

  List<ConfigDevice> get androidDevices => devices
      .where((device) => device.deviceType == DeviceType.android)
      .toList();

  bool get isFrameEnabled => _configInfo['frame'];

  String get recordingDir => _configInfo['recording'];

  String get archiveDir => _configInfo['archive'];

  /// Get all android and ios device names.
  List<String> get deviceNames => devices.map((device) => device.name).toList();

  ConfigDevice getDevice(String deviceName) => devices.firstWhere(
      (device) => device.name == deviceName,
      orElse: () => throw 'Error: no device configured for \'$deviceName\'');

  /// Check for active run type.
  /// Run types can only be one of [DeviceType].
  isRunTypeActive(DeviceType runType) {
    final deviceType = utils.getStringFromEnum(runType);
    return !(_configInfo['devices'][deviceType] == null ||
        _configInfo['devices'][deviceType].length == 0);
  }

  /// Check if frame is required for [deviceName].
  bool isFrameRequired(String deviceName, Orientation orientation) {
    final device = devices.firstWhere((device) => device.name == deviceName,
        orElse: () => throw 'Error: device \'$deviceName\' not found');
    // orientation over-rides frame if not in Portait (default)
    if (orientation == null) return device.isFramed;
    return (orientation == Orientation.LandscapeLeft ||
        orientation == Orientation.LandscapeRight)
        ? false
        : device.isFramed;
  }

  /// Current screenshots runtime environment
  /// (updated before start of each test)
  Future<Map> get screenshotsEnv async {
    if (isScreenShotsAvailable) {
      if (_screenshotsEnv == null) await _retrieveEnv();
      return _screenshotsEnv;
    } else {
      // output in test (hence no printStatus)
      io.stdout.writeln('Warning: screenshots runtime environment not set.');
      return Future.value({});
    }
  }

  io.File get _envStore {
    return io.File(_configInfo['staging'] + '/' + kEnvFileName);
  }

  /// Records screenshots environment before start of each test
  /// (called by screenshots)
  @visibleForTesting
  Future<void> storeEnv(Screens screens, String emulatorName, String locale,
      DeviceType deviceType, Orientation orientation) async {
    // store env for later use by tests
    final screenProps = screens.getScreen(emulatorName);
    final screenSize = screenProps == null ? null : screenProps['size'];
    final currentEnv = {
      'screen_size': screenSize,
      'locale': locale,
      'device_name': emulatorName,
      'device_type': utils.getStringFromEnum(deviceType),
      'orientation': utils.getStringFromEnum(orientation)
    };
    await _envStore.writeAsString(json.encode(currentEnv));
  }

  Future<void> _retrieveEnv() async {
    _screenshotsEnv = json.decode(await _envStore.readAsString());
  }

  List<String> _processList(List list) {
    return list.map((item) {
      return item.toString();
    }).toList();
  }

  List<ConfigDevice> _processDevices(
      Map<String, dynamic> devices, bool globalFraming) {
    Orientation _getValidOrientation(String orientation, deviceName) {
      bool _isValidOrientation(String orientation) {
        return Orientation.values.firstWhere(
                (o) => utils.getStringFromEnum(o) == orientation,
                orElse: () => null) !=
            null;
      }

      if (!_isValidOrientation(orientation)) {
        print(
            'Invalid value for \'orientation\' for device \'$deviceName\': $orientation}');
        print('Valid values:');
        for (final _orientation in Orientation.values) {
          print('  ${utils.getStringFromEnum(_orientation)}');
        }
        io.exit(1); // todo: add tool exception and throw
      }
      return utils.getEnumFromString(Orientation.values, orientation);
    }

    List<ConfigDevice> configDevices = [];

    devices.forEach((deviceType, device) {
      device?.forEach((deviceName, deviceProps) {
        final orientationVal =
            deviceProps == null ? null : deviceProps['orientation'];
        configDevices.add(ConfigDevice(
          deviceName,
          utils.getEnumFromString(DeviceType.values, deviceType),
          deviceProps == null
              ? globalFraming
              : deviceProps['frame'] ??
                  globalFraming, // device frame overrides global frame
          deviceProps == null
              ? null
              : orientationVal == null
                  ? null
                  : orientationVal is String
                      ? [_getValidOrientation(orientationVal, deviceName)]
                      : List<Orientation>.from(orientationVal.map((o) {
                          return _getValidOrientation(o, deviceName);
                        })),
          deviceProps == null ? true : deviceProps['build'] ?? true,
        ));
      });
    });

    return configDevices;
  }
}

Function eq = const ListEquality().equals;

/// Describe a config device
class ConfigDevice {
  final String name;
  final DeviceType deviceType;
  final bool isFramed;
  final List<Orientation> orientations;
  final bool isBuild;

  ConfigDevice(
    this.name,
    this.deviceType,
    this.isFramed,
    this.orientations,
    this.isBuild,
  )   : assert(name != null),
        assert(deviceType != null),
        assert(isFramed != null),
        assert(isBuild != null);

  @override
  bool operator ==(other) {
    return other is ConfigDevice &&
        other.name == name &&
        other.isFramed == isFramed &&
        eq(other.orientations, orientations) &&
        other.deviceType == deviceType &&
        other.isBuild == isBuild;
  }

  @override
  String toString() =>
      'name: $name, deviceType: ${utils.getStringFromEnum(deviceType)}, isFramed: $isFramed, orientations: $orientations, isBuild: $isBuild';
}
