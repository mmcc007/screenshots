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
  clearFilesWithExt(dirPath, kImageExtension);
  if (runMode == RunMode.normal) {
    im.deleteDiffs(dirPath);
  }
}

// ios/fastlane/screenshots/en-US/*[iPad|iPhone]*
// android/fastlane/metadata/android/en-US/images/phoneScreenshots
// android/fastlane/metadata/android/en-US/images/tenInchScreenshots
// android/fastlane/metadata/android/en-US/images/sevenInchScreenshots
/// Generate fastlane dir path for ios or android.
String getDirPath(
    DeviceType deviceType, String locale, String androidModelType) {
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
  String androidDeviceType;
  if (screenProps != null) androidDeviceType = screenProps['destName'];
  return androidDeviceType;
}

/// Clear files in a directory [dirPath] ending in [ext]
/// Create directory if none exists.
void clearFilesWithExt(String dirPath, String ext) {
  // delete files with ext
  if (Directory(dirPath).existsSync()) {
    Directory(dirPath).listSync().toList().forEach((e) {
      if (p.extension(e.path) == ext) {
        File(e.path).delete();
      }
    });
  } else {
    Directory(dirPath).createSync(recursive: true);
  }
}
