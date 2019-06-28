import 'dart:async';

import 'package:screenshots/screens.dart';
import 'package:screenshots/screenshots.dart';
import 'package:screenshots/utils.dart' as utils;

// ios/fastlane/screenshots/en-US/*[iPad|iPhone]*
// android/fastlane/metadata/android/en-US/images/phoneScreenshots
// android/fastlane/metadata/android/en-US/images/tenInchScreenshots
// android/fastlane/metadata/android/en-US/images/sevenInchScreenshots

/// Generate fastlane paths for ios and android.
String fastlaneDir(DeviceType deviceType, String locale,
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
  const kImageSuffix = 'png';

  final Map screenProps = screens.screenProps(deviceName);

  final dirPath = fastlaneDir(deviceType, locale, '', screenProps['destName']);

  print('Clearing images in $dirPath for \'$deviceName\'...');
  if (deviceType == DeviceType.ios) {
    // only delete images ending with .png
    // for compatability with FrameIt
    // (see https://github.com/mmcc007/screenshots/issues/61)
    utils.clearFilesWithSuffix(dirPath, kImageSuffix);
  } else {
    await utils.clearDirectory(dirPath);
  }
}

/// clear configured fastlane directories.
Future clearFastlaneDirs(Map config, Screens screens) async {
//  final config = Config('test/test_config.yaml').config;
//  final Map screens = await Screens().init();

  if (config['devices']['ios'] != null) {
    for (String emulatorName in config['devices']['ios'].keys) {
      for (final locale in config['locales']) {
        await clearFastlaneDir(screens, emulatorName, locale, DeviceType.ios);
      }
    }
  }
  if (config['devices']['android'] != null) {
    for (String simulatorName in config['devices']['android'].keys) {
      for (final locale in config['locales']) {
        await clearFastlaneDir(
            screens, simulatorName, locale, DeviceType.android);
      }
    }
  }
}
