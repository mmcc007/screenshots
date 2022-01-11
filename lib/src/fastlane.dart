import 'dart:async';

import 'package:screenshots/src/image_magick.dart';
import 'package:screenshots/src/resources.dart';
import 'package:tool_base/tool_base.dart' hide Config;

import 'config.dart';
import 'screens.dart';
import 'package:path/path.dart' as p;
import 'globals.dart';

/// clear configured fastlane directories.
Future clearFastlaneDirs(
    Config config, Screens screens, RunMode runMode) async {
  if (config.isRunTypeActive(DeviceType.android)) {
    for (var device in config.androidDevices) {
      for (final locale in config.locales) {
        await _clearFastlaneDir(
            screens, device.name, locale, DeviceType.android, runMode);
      }
    }
  }
  if (config.isRunTypeActive(DeviceType.ios)) {
    for (var device in config.iosDevices) {
      for (final locale in config.locales) {
        await _clearFastlaneDir(
            screens, device.name, locale, DeviceType.ios, runMode);
      }
    }
  }
}

/// Clear images destination.
Future _clearFastlaneDir(Screens screens, String deviceName, String locale,
    DeviceType deviceType, RunMode runMode) async {
  final screenProps = screens.getScreen(deviceName);
  var androidModelType = getAndroidModelType(screenProps, deviceName);

  final dirPath = getDirPath(deviceType, locale, androidModelType);

  printStatus('Clearing images in $dirPath for \'$deviceName\'...');
  // delete images ending with .kImageExtension
  // for compatibility with FrameIt
  // (see https://github.com/mmcc007/screenshots/issues/61)
  deleteMatchingFiles(dirPath, RegExp('$deviceName.*.$kImageExtension'));
  if (runMode == RunMode.normal) {
    // delete all diff files (if any)
    deleteMatchingFiles(
        dirPath, RegExp('.*${ImageMagick.kDiffSuffix}.$kImageExtension'));
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
String getAndroidModelType(ScreenInfo? screen, String deviceName) {
  var androidDeviceType = kFastlanePhone;
  if (screen == null) {
    printStatus(
        'Warning: using default value \'$kFastlanePhone\' in \'$deviceName\' fastlane directory.');
  } else {
    androidDeviceType = screen.destName!;
  }
  return androidDeviceType;
}

/// Clears files matching a pattern in a directory.
/// Creates directory if none exists.
void deleteMatchingFiles(String dirPath, RegExp pattern) {
  if (fs.directory(dirPath).existsSync()) {
    fs.directory(dirPath).listSync().toList().forEach((e) {
      if (pattern.hasMatch(p.basename(e.path))) {
        fs.file(e.path).deleteSync();
      }
    });
  } else {
    fs.directory(dirPath).createSync(recursive: true);
  }
}
