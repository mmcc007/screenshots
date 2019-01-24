import 'package:screenshots/screenshots.dart';

//# ios/fastlane/screenshots/en-US/*[iPad|iPhone]*
//# android/fastlane/metadata/android/en-US/images/phoneScreenshots
//# android/fastlane/metadata/android/en-US/images/tenInchScreenshots
//# android/fastlane/metadata/android/en-US/images/sevenInchScreenshots

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
//      path = '$iosPrefix/$locale/$screenName';
      // todo: name files correctly
      path = '$iosPrefix/$locale';
  }
  return path;
}
