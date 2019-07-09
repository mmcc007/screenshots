import 'dart:async';

import 'screens.dart';
import 'utils.dart' as utils;

import 'globals.dart';
// ios/fastlane/screenshots/en-US/*[iPad|iPhone]*
// android/fastlane/metadata/android/en-US/images/phoneScreenshots
// android/fastlane/metadata/android/en-US/images/tenInchScreenshots
// android/fastlane/metadata/android/en-US/images/sevenInchScreenshots

/// Generate fastlane paths for ios and android.
String fastlaneDir(
    DeviceType deviceType, String locale, String androidDeviceType) {
  const androidPrefix = 'android/fastlane/metadata/android';
  const iosPrefix = 'ios/fastlane/screenshots';
  String path;
  switch (deviceType) {
    case DeviceType.android:
      path = '$androidPrefix/$locale/images/${androidDeviceType}Screenshots';
      break;
    case DeviceType.ios:
      path = '$iosPrefix/$locale';
  }
  return path;
}

/// Clear image destination.
Future _clearFastlaneDir(
    Screens screens, deviceName, locale, DeviceType deviceType) async {
  const kImageSuffix = 'png';

  final Map screenProps = screens.screenProps(deviceName);
  String androidDeviceType = getAndroidDeviceType(screenProps);

  final dirPath = fastlaneDir(deviceType, locale, androidDeviceType);

  print('Clearing images in $dirPath for \'$deviceName\'...');
  // only delete images ending with .png
  // for compatability with FrameIt
  // (see https://github.com/mmcc007/screenshots/issues/61)
  utils.clearFilesWithSuffix(dirPath, kImageSuffix);
}

String getAndroidDeviceType(Map screenProps) {
  String androidDeviceType;
  if (screenProps != null) androidDeviceType = screenProps['destName'];
  return androidDeviceType;
}

/// clear configured fastlane directories.
Future clearFastlaneDirs(Map config, Screens screens) async {
  if (config['devices']['android'] != null) {
    for (String deviceName in config['devices']['android'].keys) {
      for (final locale in config['locales']) {
        await _clearFastlaneDir(
            screens, deviceName, locale, DeviceType.android);
      }
    }
  }
  if (config['devices']['ios'] != null) {
    for (String deviceName in config['devices']['ios'].keys) {
      for (final locale in config['locales']) {
        await _clearFastlaneDir(screens, deviceName, locale, DeviceType.ios);
      }
    }
  }
}
