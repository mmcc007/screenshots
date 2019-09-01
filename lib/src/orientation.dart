import 'android/android_sdk.dart';
import 'base/process.dart';
import 'globals.dart';
import 'utils.dart' as utils;

enum Orientation { Portrait, LandscapeRight, PortraitUpsideDown, LandscapeLeft }

/// Change orientation of a running emulator or simulator.
/// (No known way of supporting real devices.)
void changeDeviceOrientation(DeviceType deviceType, Orientation orientation,
    {String deviceId, String scriptDir}) {
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
      cmd([
        getAdbPath(androidSdk),
        '-s',
        deviceId,
        'shell',
        'settings',
        'put',
        'system',
        'user_rotation',
        androidOrientations[_orientation]
      ]);
      break;
    case DeviceType.ios:
      // requires permission when run for first time
      cmd([
        'osascript',
        '$scriptDir/$sim_orientation_script',
        iosOrientations[_orientation]
      ]);
      break;
  }
}

Orientation getOrientationEnum(String orientation) {
  final _orientation =
      utils.getEnumFromString<Orientation>(Orientation.values, orientation);
  _orientation == null
      ? throw 'Error: orientation \'$orientation\' not found'
      : null;
  return _orientation;
}
