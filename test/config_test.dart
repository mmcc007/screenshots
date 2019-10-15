import 'dart:io' as io;

import 'package:screenshots/screenshots.dart';
import 'package:screenshots/src/config.dart';
import 'package:screenshots/src/orientation.dart';
import 'package:screenshots/src/screens.dart';
import 'package:screenshots/src/utils.dart';
import 'package:test/test.dart';

import 'src/common.dart';

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
        null,
      );
      final expectedAndroidName = 'Nexus 6P';
      final expectedGlobalFrame = true;
      final expectedAndroidDevice = ConfigDevice(
        expectedAndroidName,
        DeviceType.android,
        expectedGlobalFrame,
        orientation,
        null,
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
      expect(config.recordingDir, expectedRecording);
      expect(config.archiveDir, expectedArchive);
      expect(config.getDevice(expectedAndroidName), expectedAndroidDevice);
      expect(config.getDevice(expectedAndroidName), isNot(expectedIosDevice));
      expect(config.deviceNames..sort(),
          equals([expectedAndroidName, expectedIosName]..sort()));
    });

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

    test('store and retrieve environment', () async {
      final tmpDir = '/tmp/screenshots_test_env';
      clearDirectory(tmpDir);
      String configStr = '''
        staging: $tmpDir
      ''';
      final config = Config(configStr: configStr);
      final screens = await Screens();
      await screens.init();
      final orientation = 'Portrait';

      final env = {
        'screen_size': '1440x2560',
        'locale': 'en_US',
        'device_name': 'Nexus 6P',
        'device_type': 'android',
        'orientation': orientation
      };

      // called by screenshots before test
      await config.storeEnv(
          screens,
          env['device_name'],
          env['locale'],
          getEnumFromString(DeviceType.values, env['device_type']),
          getEnumFromString(Orientation.values, orientation));

      // called by test
      // simulate no screenshots available
      Config testConfig = Config(configStr: configStr);
      expect(await testConfig.screenshotsEnv, {});

      // simulate screenshots available
      final configPath = '$tmpDir/screenshots.yaml';
      await io.File(configPath).writeAsString(configStr);
      testConfig = Config(configPath: configPath);
      expect(await testConfig.screenshotsEnv, env);
    });
  });
}
