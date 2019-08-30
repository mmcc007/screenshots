import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:screenshots/src/orientation.dart';

import 'screens.dart';
import 'utils.dart' as utils;
import 'globals.dart';

///
/// Config info used to process screenshots for android and ios.
///
class Config {
  Config({this.configPath = kConfigFileName, String configStr}) {
    if (configStr != null) {
      _configInfo = utils.parseYamlStr(configStr);
    } else {
      _configInfo = utils.parseYamlFile(configPath);
    }
  }

  final String configPath;
  Map _configInfo;
  Map _screenshotsEnv; // current screenshots env

  List<String> get tests => _processList(_configInfo['tests']);
  String get stagingDir => _configInfo['staging'];
  List<String> get locales => _processList(_configInfo['locales']);
  List<ConfigDevice> get devices =>
      _processDevices(configInfo['devices'], isFrameEnabled);
  List<ConfigDevice> get iosDevices =>
      devices.where((device) => device.deviceType == DeviceType.ios).toList();
  List<ConfigDevice> get androidDevices => devices
      .where((device) => device.deviceType == DeviceType.android)
      .toList();
  bool get isFrameEnabled => _configInfo['frame'];
  String get recordingPath => _configInfo['recording'];
  String get archivePath => _configInfo['archive'];

  ConfigDevice getDevice(String deviceName) =>
      devices.firstWhere((device) => device.name == deviceName);

  /// Check for active run type.
  /// Runs can only be one of [DeviceType].
  isRunTypeActive(DeviceType runType) {
    final deviceType = utils.getStringFromEnum(runType);
    return _configInfo['devices'][deviceType] != null;
  }

  /// Check if frame is required for [deviceName].
  bool isFrameRequired(String deviceName) {
    final device = devices.firstWhere((device) => device.name == deviceName,
        orElse: () => throw 'Error: device \'$deviceName\' not found');
    return device.isFramed;
  }

  /// Get configuration information for supported devices
  Map get configInfo => _configInfo;

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
      String deviceType, String orientation) async {
    // store env for later use by tests
    final screenProps = screens.getScreen(emulatorName);
    final screenSize = screenProps == null ? null : screenProps['size'];
    final currentEnv = {
      'screen_size': screenSize,
      'locale': locale,
      'device_name': emulatorName,
      'device_type': deviceType,
      'orientation': orientation
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

  List<ConfigDevice> _processDevices(Map devices, bool globalFraming) {
    List<ConfigDevice> configDevices = [];

    devices.forEach((deviceType, device) {
      device.forEach((deviceName, deviceProps) {
        configDevices.add(ConfigDevice(
            deviceName,
            utils.getEnumFromString(DeviceType.values, deviceType),
            deviceProps == null
                ? globalFraming
                : deviceProps['frame'] ??
                    globalFraming, // device frame overrides global frame
            deviceProps == null
                ? null
                : deviceProps['orientation'] == null
                    ? null
                    : utils.getEnumFromString(
                        Orientation.values, deviceProps['orientation'])));
      });
    });

    return configDevices;
  }
}

/// Describe a config device
class ConfigDevice {
  final String name;
  final DeviceType deviceType;
  final bool isFramed;
  final Orientation orientation;

  const ConfigDevice(
      this.name, this.deviceType, this.isFramed, this.orientation)
      : assert(name != null),
        assert(deviceType != null),
        assert(isFramed != null);

  @override
  bool operator ==(other) {
    return other is ConfigDevice &&
        other.name == name &&
        other.isFramed == isFramed &&
        other.orientation == orientation &&
        other.deviceType == deviceType;
  }

  @override
  String toString() =>
      'name: $name, deviceType: ${utils.getStringFromEnum(deviceType)}, isFramed: $isFramed, orientation: ${utils.getStringFromEnum(orientation)}';
}
