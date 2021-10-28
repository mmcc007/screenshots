import 'package:collection/collection.dart';
import 'package:screenshots/generated/screens/screens.dart';
import 'package:screenshots/src/resources.dart';

import 'globals.dart';

/// Manage screens file.
class Screens {
  const Screens();

  /// Get screen properties for [deviceName].
  ScreenInfo? getScreen(String deviceName) =>
      screens.where((si) => si.devices.contains(deviceName)).firstOrNull;

  /// Get [DeviceType] for [deviceName].
  DeviceType? getDeviceType(String deviceName) =>
      getScreen(deviceName)?.deviceType;

  /// Test if screen is used for identifying android model type.
  static bool isAndroidModelTypeScreen(ScreenInfo info) => info.size == null;

  /// Get supported device names by [os]
  List<String> getSupportedDeviceNamesByOs(DeviceType os) {
    var devices = screens
        .where((si) => si.deviceType == os)
        .where((si) => !isAndroidModelTypeScreen(si))
        .fold(<String>[], (List<String> sum, si) => sum..addAll(si.devices));

    // sort iPhone devices first
    devices.sort((v1, v2) {
      if ('$v1'.contains('iPhone') && '$v2'.contains('iPad')) return -1;
      if ('$v1'.contains('iPad') && '$v2'.contains('iPhone')) return 1;
      return v1.compareTo(v2);
    });

    return devices;
  }
}
