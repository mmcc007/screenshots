import 'package:screenshots/screenshots.dart';
import 'package:screenshots/src/config.dart';
import 'package:screenshots/src/orientation.dart';
import 'package:screenshots/src/utils.dart';
import 'package:test/test.dart';

main() {
  group('config', () {
    test('getters', () {
      final expectedTest = 'test_driver/main.dart';
      final expectedStaging = '/tmp/screenshots';
      final expectedLocale = 'en-US';
      final expectedIosName = 'iPhone XS Max';
      final expectedIosFrame = false;
      final expectedOrientation = 'LandscapeRight';
      final orientation =
          getEnumFromString(Orientation.values, expectedOrientation);
      final expectedIosDevice = ConfigDevice(
        expectedIosName,
        DeviceType.ios,
        expectedIosFrame,
        orientation,
      );
      final expectedAndroidName = 'Nexus 6P';
      final expectedGlobalFrame = true;
      final expectedAndroidDevice = ConfigDevice(
        expectedAndroidName,
        DeviceType.android,
        expectedGlobalFrame,
        orientation,
      );
      final expectedRecording = '/tmp/screenshots_record';
      final expectedArchive = '/tmp/screenshots_archive';
      final configStr = '''
      tests:
        - $expectedTest
      staging: $expectedStaging
      locales:
        - $expectedLocale
      devices:
        ios:
          $expectedIosName:
            frame: $expectedIosFrame
            orientation: $expectedOrientation
        android:
          $expectedAndroidName:
            orientation: $expectedOrientation
      frame: $expectedGlobalFrame
      recording: $expectedRecording
      archive: $expectedArchive
      ''';
      final config = Config(configStr: configStr);

      expect(config.tests, [expectedTest]);
      expect(config.stagingDir, expectedStaging);
      expect(config.locales, [expectedLocale]);
      expect(config.devices, {
        'android': expectedAndroidDevice,
        'ios': expectedIosDevice,
      });
      expect(config.devices['android'], equals(expectedAndroidDevice));
      expect(config.devices['ios'], isNot(equals(expectedAndroidDevice)));
      expect(config.isFrameEnabled, expectedGlobalFrame);
      expect(config.recordingPath, expectedRecording);
      expect(config.archivePath, expectedArchive);
      expect(config.getDevice(expectedAndroidName), expectedAndroidDevice);
      expect(config.getDevice(expectedAndroidName), isNot(expectedIosDevice));
    });
  });
}
