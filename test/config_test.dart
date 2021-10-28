import 'dart:io' as io;

import 'package:screenshots/screenshots.dart';
import 'package:screenshots/src/config.dart';
import 'package:screenshots/src/orientation.dart';
import 'package:screenshots/src/screens.dart';
import 'package:screenshots/src/utils.dart';
import 'package:test/test.dart';

import 'src/common.dart';

void main() {
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
        [orientation],
        true,
      );
      final expectedAndroidName = 'Nexus 6P';
      final expectedGlobalFrame = true;
      final expectedAndroidDevice = ConfigDevice(
        expectedAndroidName,
        DeviceType.android,
        expectedGlobalFrame,
        [orientation],
        true,
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
            orientation: 
              - $expectedOrientation
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

    test('backward compatible orientation', () {
      var configStr = '''
        devices:
          android:
            device name:
              orientation: 
                - Portrait
        frame: true
        ''';
      var config = Config(configStr: configStr);
      expect(config.devices[0].orientations[0], Orientation.Portrait);
      configStr = '''
        devices:
          android:
            device name:
              orientation: Portrait
        frame: true
        ''';
      config = Config(configStr: configStr);
      expect(config.devices[0].orientations[0], Orientation.Portrait);
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
      var config = Config(configStr: configIosOnly);
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
      final deviceName = 'Nexus 6P';
      var configStr = '''
        devices:
          android:
            $deviceName:
        frame: true
        ''';
      var config = Config(configStr: configStr);
      expect(config.isFrameRequired(deviceName, null), isTrue);
      configStr = '''
        devices:
          android:
            $deviceName:
              frame: false
        frame: true
        ''';
      config = Config(configStr: configStr);
      expect(config.isFrameRequired(deviceName, null), isFalse);
      configStr = '''
        devices:
          android:
            $deviceName:
              orientation: 
                - Portrait
                - LandscapeRight
        frame: true
        ''';
      config = Config(configStr: configStr);
      final device = config.getDevice(deviceName);
      expect(
          config.isFrameRequired(deviceName, device.orientations[0]), isTrue);
      expect(
          config.isFrameRequired(deviceName, device.orientations[1]), isFalse);
    });

    test('store and retrieve environment', () async {
      final tmpDir = '/tmp/screenshots_test_env';
      clearDirectory(tmpDir);
      var configStr = '''
        staging: $tmpDir
      ''';
      final config = Config(configStr: configStr);
      final screens = Screens();
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
          env['device_name']!,
          env['locale']!,
          getEnumFromString(DeviceType.values, env['device_type']!),
          getEnumFromString(Orientation.values, orientation));

      // called by test
      // simulate no screenshots available
      var testConfig = Config(configStr: configStr);
      expect(await testConfig.screenshotsEnv, {});

      // simulate screenshots available
      final configPath = '$tmpDir/screenshots.yaml';
      await io.File(configPath).writeAsString(configStr);
      testConfig = Config(configPath: configPath);
      expect(await testConfig.screenshotsEnv, env);
    });
  });
}
