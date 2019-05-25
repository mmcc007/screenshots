import 'package:screenshots/config.dart';
import 'package:screenshots/process_images.dart';
import 'package:screenshots/screens.dart';
import 'package:screenshots/screenshots.dart';
import 'package:test/test.dart';
import 'package:screenshots/fastlane.dart' as fastlane;

void main() {
  test('config info for app', () {
    final expected = {
      'tests': ['example/test_driver/main.dart'],
      'locales': ['en-US'],
      'frame': true,
      'devices': {
        'android': {'Nexus 5X': null},
        'ios': {
          'iPhone 7 Plus': {'frame': false},
          'iPhone X': null
        }
      },
      'staging': '/tmp/screenshots'
    };

    final Config config = Config('test/screenshots_test.yaml');
    Map appConfig = config.config;
    expect(appConfig, expected);
  });

  test('validate config file', () async {
    final Screens screens = Screens();
    await screens.init();
    final Config config = Config('test/screenshots_test.yaml');
    expect(await config.validate(screens), true);
  });

  test('clear all destination directories on init', () async {
    final Screens screens = Screens();
    await screens.init();
    final Config config = Config('test/screenshots_test.yaml');
    await fastlane.clearFastlaneDirs(config.config, screens);
  });

  test('check if frame is needed', () {
    final config = {
      'tests': ['example/test_driver/main.dart'],
      'locales': ['en-US'],
      'frame': true,
      'devices': {
        'android': {'Nexus 5X': null},
        'ios': {
          'iPhone 7 Plus': {'frame': false},
          'iPhone X': null
        }
      },
      'staging': '/tmp/screenshots'
    };

    expect(isFrameRequired(config, DeviceType.ios, 'iPhone X'), true);
    expect(isFrameRequired(config, DeviceType.ios, 'iPhone 7 Plus'), false);
    expect(isFrameRequired(config, DeviceType.android, 'Nexus 5X'), true);
  });
}
