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
      expect(config.androidDevices, equals([expectedAndroidDevice]));
      expect(config.iosDevices, equals([expectedIosDevice]));
      expect(config.iosDevices, isNot(equals([expectedAndroidDevice])));
      expect(config.isFrameEnabled, expectedGlobalFrame);
      expect(config.recordingPath, expectedRecording);
      expect(config.archivePath, expectedArchive);
      expect(config.getDevice(expectedAndroidName), expectedAndroidDevice);
      expect(config.getDevice(expectedAndroidName), isNot(expectedIosDevice));
      expect(
          config.deviceNames, equals([expectedAndroidName, expectedIosName]));
    });

    group('methods', () {
      test('active run type', () {
        final configIosOnly = '''
        devices:
          ios:
            iPhone X:
      ''';
        final configAndroidOnly = '''
        devices:
          ios: # check for empty devices
          android:
            Nexus 6P:
      ''';
        final configBoth = '''
        devices:
          ios:
            iPhone X:
          android:
            Nexus 6P:
      ''';
        final configNeither = '''
        devices:
          ios:
          android:
      ''';
//      Map config = utils.parseYamlStr(configIosOnly);
        Config config = Config(configStr: configIosOnly);
        expect(config.isRunTypeActive(DeviceType.ios), isTrue);
        expect(config.isRunTypeActive(DeviceType.android), isFalse);

        config = Config(configStr: configAndroidOnly);
        expect(config.isRunTypeActive(DeviceType.ios), isFalse);
        expect(config.isRunTypeActive(DeviceType.android), isTrue);

        config = Config(configStr: configBoth);
        expect(config.isRunTypeActive(DeviceType.ios), isTrue);
        expect(config.isRunTypeActive(DeviceType.android), isTrue);

        config = Config(configStr: configNeither);
        expect(config.isRunTypeActive(DeviceType.ios), isFalse);
        expect(config.isRunTypeActive(DeviceType.android), isFalse);
      });

      test('isFrameRequired', () {
        String configStr = '''
        devices:
          android:
            Nexus 6P:
        frame: true
        ''';
        Config config = Config(configStr: configStr);
        expect(config.isFrameRequired('Nexus 6P'), isTrue);
        configStr = '''
        devices:
          android:
            Nexus 6P:
              frame: false
        frame: true
        ''';
        config = Config(configStr: configStr);
        expect(config.isFrameRequired('Nexus 6P'), isFalse);
      });
    });
  });
}
