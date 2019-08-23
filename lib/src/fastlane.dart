import 'dart:async';
import 'dart:io';

import 'screens.dart';
import 'package:path/path.dart' as p;
import 'globals.dart';

/// clear configured fastlane directories.
Future clearFastlaneDirs(Map config, Screens screens, RunMode runMode) async {
  if (config['devices']['android'] != null) {
    for (String deviceName in config['devices']['android'].keys) {
      for (final locale in config['locales']) {
        await _clearFastlaneDir(
            screens, deviceName, locale, DeviceType.android, runMode);
      }
    }
  }
  if (config['devices']['ios'] != null) {
    for (String deviceName in config['devices']['ios'].keys) {
      for (final locale in config['locales']) {
        await _clearFastlaneDir(
            screens, deviceName, locale, DeviceType.ios, runMode);
      }
    }
  }
}

/// Clear images destination.
Future _clearFastlaneDir(Screens screens, String deviceName, String locale,
    DeviceType deviceType, RunMode runMode) async {
  final Map screenProps = screens.screenProps(deviceName);
  String androidModelType = getAndroidModelType(screenProps);

  final dirPath = getDirPath(deviceType, locale, androidModelType);

  print('Clearing images in $dirPath for \'$deviceName\'...');
  // delete images ending with .kImageExtension
  // for compatibility with FrameIt
  // (see https://github.com/mmcc007/screenshots/issues/61)
  deleteMatchingFiles(dirPath, RegExp('$deviceName.*.$kImageExtension'));
  if (runMode == RunMode.normal) {
    im.deleteDiffs(dirPath);
  }
}

const kFastlanePhone = 'phone';
const kFastlaneSevenInch = 'sevenInch';
const kFastlaneTenInch = 'tenInch';
// ios/fastlane/screenshots/en-US/*[iPad|iPhone]*
// android/fastlane/metadata/android/en-US/images/phoneScreenshots
// android/fastlane/metadata/android/en-US/images/tenInchScreenshots
// android/fastlane/metadata/android/en-US/images/sevenInchScreenshots
/// Generate fastlane dir path for ios or android.
String getDirPath(
    DeviceType deviceType, String locale, String androidModelType) {
  locale = locale.replaceAll('_', '-'); // in case canonicalized
  const androidPrefix = 'android/fastlane/metadata/android';
  const iosPrefix = 'ios/fastlane/screenshots';
  String dirPath;
  switch (deviceType) {
    case DeviceType.android:
      dirPath = '$androidPrefix/$locale/images/${androidModelType}Screenshots';
      break;
    case DeviceType.ios:
      dirPath = '$iosPrefix/$locale';
  }
  return dirPath;
}

/// Get android model type (phone or tablet screen size).
String getAndroidModelType(Map screenProps) {
  String androidDeviceType = kFastlanePhone;
  if (screenProps == null) {
    print(
        'Warning: using default value \'$kFastlanePhone\' in fastlane directory.');
  } else {
    androidDeviceType = screenProps['destName'];
  }
  return androidDeviceType;
}

/// Clears files matching a pattern in a directory.
/// Creates directory if none exists.
void deleteMatchingFiles(String dirPath, RegExp pattern) {
  if (Directory(dirPath).existsSync()) {
    Directory(dirPath).listSync().toList().forEach((e) {
      if (pattern.hasMatch(p.basename(e.path))) {
        File(e.path).deleteSync();
      }
    });
  } else {
    Directory(dirPath).createSync(recursive: true);
  }
}
