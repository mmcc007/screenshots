import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:screenshots/src/screens.dart';

import 'globals.dart';
import 'resources.dart';
import 'utils.dart' as utils;

const kEnvConfigPath = 'SCREENSHOTS_YAML';

class ConfigException implements Exception {
  const ConfigException(this.message);

  final String message;
}

class ScreenshotsEnv {
  final ScreenInfo screen;
  final ConfigDevice device;
  final String locale;
  final Orientation orientation;

  ScreenshotsEnv({
    required this.screen,
    required this.device,
    required this.locale,
    required this.orientation,
  });

  static ScreenshotsEnv fromJson(Screens screens, Map<String, dynamic> map) =>
      ScreenshotsEnv(
          screen: screens.getScreen(map['screen'])!,
          device: map['device'],
          locale: map['locale'],
          orientation: utils.getEnumFromString(Orientation.values, map['orientation']),
      );

  Map<String, String?> toJson() => {
        'screen': screen.name,
        'locale': locale,
        'device': device.name,
        'orientation': utils.getStringFromEnum(orientation),
      };
}

/// Config info used to manage screenshots for android and ios.
// Note: should not have context dependencies as is also used in driver.
// todo: yaml validation
class Config {
  factory Config({String configPath = kConfigFileName, String? configStr}) {
    Map<String, dynamic> _configInfo = {};

    if (configStr != null) {
      // used by tests
      _configInfo = utils.parseYamlStr(configStr);
    } else {
      final envConfigPath = io.Platform.environment[kEnvConfigPath];
      if (envConfigPath == null) {
        // used by command line and by driver if using kConfigFileName
        _configInfo = utils.parseYamlFile(configPath);
      } else {
        // used by driver
        _configInfo = utils.parseYamlFile(envConfigPath);
      }
    }

    var isFrameEnabled = _configInfo['frame'] as bool? ?? false;

    var devices = _processDevices(_configInfo['devices'], isFrameEnabled);
    var tests = _processList(_configInfo['tests']);
    var recording = _configInfo['recording'];
    var locales = _processList(_configInfo['locales']);
    var staging = _configInfo['staging'];
    var archive = _configInfo['archive'];

    return Config._(
        devices: devices,
        isFrameEnabled: isFrameEnabled,
        tests: tests,
        recordingDir: recording,
        locales: locales,
        stagingDir: staging,
        archiveDir: archive);
  }

  Config._({required this.devices,
    required this.isFrameEnabled,
    required this.tests,
    required this.stagingDir,
    required this.locales,
    required this.archiveDir,
    required this.recordingDir,});

  ScreenshotsEnv? _screenshotsEnv;
  final List<ConfigDevice> devices;

  // Getters
  List<String> tests;

  String stagingDir;

  List<String> locales;

  List<ConfigDevice> get iosDevices =>
      devices.where((device) => device.deviceType == DeviceType.ios).toList();

  List<ConfigDevice> get androidDevices =>
      devices
          .where((device) => device.deviceType == DeviceType.android)
          .toList();

  bool isFrameEnabled;

  String? recordingDir;

  String? archiveDir;

  ConfigDevice? getDevice(String deviceName) =>
      devices
          .where((device) => device.name == deviceName)
          .firstOrNull;

  /// Check for active run type.
  /// Run types can only be one of [DeviceType].
  bool isRunTypeActive(DeviceType deviceType) =>
      devices
          .where((element) => element.deviceType == deviceType)
          .isNotEmpty;

  /// Check if frame is required for [deviceName].
  bool isFrameRequired(String deviceName, Orientation? orientation) {
    final device = devices.firstWhere((device) => device.name == deviceName,
        orElse: () => throw 'Error: device \'$deviceName\' not found');
    // orientation over-rides frame if not in Portrait (default)
    return device.isFrameRequired(orientation);
  }

  /// Current screenshots runtime environment
  /// (updated before start of each test)
  Future<ScreenshotsEnv> get screenshotsEnv async {
    return _screenshotsEnv ??= await _retrieveEnv();
  }

  io.File get _envStore => io.File(stagingDir + '/' + kEnvFileName);

  /// Records screenshots environment before start of each test
  /// (called by screenshots)
  @visibleForTesting
  Future<void> storeEnv(ScreenshotsEnv env) async {
    // store env for later use by tests
    await _envStore.writeAsString(json.encode(env.toJson()));
  }

  Future<ScreenshotsEnv> _retrieveEnv() async => ScreenshotsEnv.fromJson(
      Screens(), json.decode(await _envStore.readAsString()));

  static List<String> _processList(List list) {
    return list.map((item) {
      return item.toString();
    }).toList();
  }

  static String? _getString(Map<String, dynamic> map, String key) {
    var val = map[key];
    if (val == null || val is String) {
      return val;
    }

    if (val is bool) {
      return val.toString();
    }

    print("Unknown type when looking for key $key in YAML: ${val.runtimeType}");
    io.exit(1);
  }

  static List<ConfigDevice> _processDevices(Map<String, dynamic> devices,
      bool globalFraming) {
    Orientation _getValidOrientation(String orientation, String deviceName) {
      for (var v in Orientation.values) {
        if (utils.getStringFromEnum(v) == orientation) {
          return v;
        }
      }

      print(
          'Invalid value for \'orientation\' for device \'$deviceName\': $orientation}');
      print('Valid values:');
      for (final _orientation in Orientation.values) {
        print('  ${utils.getStringFromEnum(_orientation)}');
      }
      io.exit(1); // todo: add tool exception and throw
    }

    var configDevices = <ConfigDevice>[];

    devices.forEach((deviceType, device) {
      device?.forEach((deviceName, deviceProps) {
        if (deviceProps == null || deviceProps is! Map<String, dynamic>) {
          throw ConfigException("Invalid value for device '$deviceName'");
        }

        final orientationVal = deviceProps['orientation'];
        final frame = _getString(deviceProps, 'frame') ?? globalFraming;

        configDevices.add(ConfigDevice(
          deviceName,
          utils.getEnumFromString(DeviceType.values, deviceType),
          frame == 'true',
          orientationVal == null
              ? []
              : orientationVal is String
              ? [_getValidOrientation(orientationVal, deviceName)]
              : orientationVal is List
              ? orientationVal
              .map((o) => _getValidOrientation(o, deviceName))
              .toList()
              : [],
          _getString(deviceProps, 'build') == "true",
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

  ConfigDevice(this.name,
      this.deviceType,
      this.isFramed,
      this.orientations,
      this.isBuild,);

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
      'name: $name, deviceType: ${utils.getStringFromEnum(
          deviceType)}, isFramed: $isFramed, orientations: $orientations, isBuild: $isBuild';

  bool isFrameRequired(Orientation? orientation) {
    if (orientation == null) {
      return isFramed;
    }

    return (orientation == Orientation.LandscapeLeft ||
        orientation == Orientation.LandscapeRight)
        ? false
        : isFramed;
  }
}
