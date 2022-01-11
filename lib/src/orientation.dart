import 'package:tool_base/tool_base.dart';
import 'package:tool_mobile/tool_mobile.dart';

import 'globals.dart';
import 'utils.dart' as utils;
import 'utils.dart';

const kDefaultOrientation = 'Portrait';

/// Change orientation of a running emulator or simulator.
/// (No known way of supporting real devices.)
void changeDeviceOrientation(DeviceType deviceType, Orientation orientation,
    {String? deviceId, String? scriptDir}) {
  final androidOrientations = {
    'Portrait': '0',
    'LandscapeRight': '1',
    'PortraitUpsideDown': '2',
    'LandscapeLeft': '3'
  };
  final iosOrientations = {
    'Portrait': 'Portrait',
    'LandscapeRight': 'Landscape Right',
    'PortraitUpsideDown': 'Portrait Upside Down',
    'LandscapeLeft': 'Landscape Left'
  };
  const sim_orientation_script = 'sim_orientation.scpt';
  final _orientation = utils.getStringFromEnum(orientation);
  printStatus('Setting orientation to $_orientation');
  switch (deviceType) {
    case DeviceType.android:
      var id = deviceId == null ? <String>[] : ['-s', deviceId];
      cmd([getAdbPath(androidSdk)] +
          id +
          [
            'shell',
            'settings',
            'put',
            'system',
            'user_rotation',
            androidOrientations[_orientation]!,
          ]);
      break;
    case DeviceType.ios:
      // requires permission when run for first time
      cmd([
        'osascript',
        '$scriptDir/$sim_orientation_script',
        iosOrientations[_orientation]!
      ]);
      break;
  }
}

Orientation getOrientationEnum(String orientation) =>
    utils.getEnumFromString<Orientation>(Orientation.values, orientation);
