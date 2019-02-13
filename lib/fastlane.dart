import 'package:screenshots/screens.dart';
import 'package:screenshots/screenshots.dart';
import 'package:screenshots/utils.dart' as utils;

// ios/fastlane/screenshots/en-US/*[iPad|iPhone]*
// android/fastlane/metadata/android/en-US/images/phoneScreenshots
// android/fastlane/metadata/android/en-US/images/tenInchScreenshots
// android/fastlane/metadata/android/en-US/images/sevenInchScreenshots

/// Generate fastlane paths for ios and android.
String path(DeviceType deviceType, String locale,
    [String deviceName, String screenName]) {
  const androidPrefix = 'android/fastlane/metadata/android';
  const iosPrefix = 'ios/fastlane/screenshots';
  String path;
  switch (deviceType) {
    case DeviceType.android:
      path = '$androidPrefix/$locale/images/${screenName}Screenshots';
      break;
    case DeviceType.ios:
      path = '$iosPrefix/$locale';
  }
  return path;
}

/// Clear image destination.
Future clearFastlaneDir(
    Screens screens, deviceName, locale, DeviceType deviceType) async {
  final Map screenProps = screens.screenProps(deviceName);

  final dstDir = path(deviceType, locale, '', screenProps['destName']);

  print('Clearing images in $dstDir for \'$deviceName\'...');
  await utils.clearDirectory(dstDir);
}

/// clear configured fastlane directories.
Future clearFastlaneDirs(Map config, Screens screens) async {
//  final config = Config('test/test_config.yaml').config;
//  final Map screens = await Screens().init();

  if (config['devices']['ios'] != null)
    for (String emulatorName in config['devices']['ios']) {
      for (final locale in config['locales']) {
        await clearFastlaneDir(screens, emulatorName, locale, DeviceType.ios);
      }
    }
  if (config['devices']['android'] != null)
    for (String simulatorName in config['devices']['android']) {
      for (final locale in config['locales']) {
        await clearFastlaneDir(
            screens, simulatorName, locale, DeviceType.android);
      }
    }
}
