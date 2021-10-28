import 'dart:async';
import 'dart:convert';
// import 'package:resource/resource.dart';
import 'globals.dart';
import 'utils.dart' as utils;

/// Manage screens file.
class Screens {
  static const _screensPath = 'resources/screens.yaml';
  Map _screens = {};

  /// Get screens yaml file from resources and parse.
  Future<void> init() async {
    // final resource = Resource('package:screenshots/$_screensPath');
    // String screens = await resource.readAsString(encoding: utf8);
    // _screens = utils.parseYamlStr(screens);
    throw 'trygvis';
  }

  /// Get screen information
  Map get screens => _screens;

  /// Get screen properties for [deviceName].
  Map getScreen(String deviceName) {
    var screenProps = {};
    screens.values.forEach((osScreens) {
      osScreens.values.forEach((_screenProps) {
        if (_screenProps['devices'].contains(deviceName)) {
          screenProps = _screenProps;
        }
      });
    });
    return screenProps;
  }

  /// Get [DeviceType] for [deviceName].
  DeviceType getDeviceType(String deviceName) {
    DeviceType deviceType;
    for (var kv in screens.entries) {
      var osScreen = kv.value;
      if(osScreen is Map<String, dynamic>) {
        if (osScreen['devices'].contains(deviceName)) {
          return utils.getEnumFromString(DeviceType.values, kv.key as String);
        }
      }
    }

    throw Exception("Could not determine device type");
  }

  /// Test if screen is used for identifying android model type.
  static bool isAndroidModelTypeScreen(Map screenProps) =>
      screenProps['size'] == null;

  /// Get supported device names by [os]
  List<String> getSupportedDeviceNamesByOs(String os) {
    final deviceNames = <String>[];
    screens.forEach((osType, osScreens) {
      if (osType == os) {
        osScreens.forEach((screenId, screenProps) {
          // omit devices that have screens that are
          // only used to identify android model type
          if (!Screens.isAndroidModelTypeScreen(screenProps)) {
            for (String device in screenProps['devices']) {
              deviceNames.add(device);
            }
          }
        });
      }
    });
    // sort iPhone devices first
    deviceNames.sort((v1, v2) {
      if ('$v1'.contains('iPhone') && '$v2'.contains('iPad')) return -1;
      if ('$v1'.contains('iPad') && '$v2'.contains('iPhone')) return 1;
      return v1.compareTo(v2);
    });

    return deviceNames;
  }
}
