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
  Map<String, ConfigDevice> get devices =>
      _processDevices(configInfo['devices'], isFrameEnabled);
  bool get isFrameEnabled => _configInfo['frame'];
  String get recordingPath => _configInfo['recording'];
  String get archivePath => _configInfo['archive'];

  ConfigDevice getDevice(String deviceName) =>
      devices.values.firstWhere((device) => device.name == deviceName);

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

  Map<String, ConfigDevice> _processDevices(
      Map devices, bool isFramingEnabled) {
    return devices.map((deviceType, device) {
      return MapEntry(
          deviceType,
          device.map((deviceName, deviceProps) {
            return MapEntry(
                'key',
                ConfigDevice(
                    deviceName,
                    utils.getEnumFromString(DeviceType.values, deviceType),
                    deviceProps['frame'] ??
                        isFramingEnabled, // device frame overrides global frame
                    utils.getEnumFromString(
                        Orientation.values, deviceProps['orientation'])));
          })['key']);
    });
  }
}

/// Describe a config device
class ConfigDevice {
  final String name;
  final DeviceType deviceType;
  final bool isFramed;
  final Orientation orientation;

  ConfigDevice(this.name, this.deviceType, this.isFramed, this.orientation);

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
