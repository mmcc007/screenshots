import 'dart:io';

import 'package:screenshots/src/config.dart';
import 'package:screenshots/src/daemon_client.dart';
import 'package:screenshots/src/globals.dart';
import 'package:screenshots/src/screens.dart';
import 'package:screenshots/src/validate.dart';
import 'package:test/test.dart';
import 'package:screenshots/src/fastlane.dart' as fastlane;
import 'package:yaml/yaml.dart';

import 'src/common.dart';

final screenshotsYaml = '''
# Screen capture tests
tests:
  - example/test_driver/main.dart

# Interim location of screenshots from tests before processing
staging: /tmp/screenshots

# A list of locales supported in app
locales:
#  - fr_CA
  - en_US
#  - de_DE

# A list of devices to emulate
devices:
  ios:
    iPhone 5c:
      frame: false
    iPhone X:
    iPhone 7 Plus:
      frame: false
#    - iPad Pro (12.9-inch) (2nd generation)
#   "iPhone 6",
#   "iPhone 6 Plus",
#   "iPhone 5",
#   "iPhone 4s",
#   "iPad Retina",
#   "iPad Pro"
  android:
    Nexus 5X:

# Frame screenshots
frame: true
''';

void main() {
  test('config info for app from string', () {
    final expected = {
      'tests': ['example/test_driver/main.dart'],
      'locales': ['en_US'],
      'frame': true,
      'devices': {
        'android': {'Nexus 5X': null},
        'ios': {
          'iPhone 7 Plus': {'frame': false},
          'iPhone X': null,
          'iPhone 5c': {'frame': false}
        }
      },
      'staging': '/tmp/screenshots'
    };

    final Map screenshotsConfig = loadYaml(screenshotsYaml);
    expect(screenshotsConfig, expected);
  });

  test('validate test paths', () async {
    final mainPath = 'example/test_driver/main.dart';
    final testPath = 'example/test_driver/main_test.dart';
    final bogusPath = 'example/test_driver/non_existant.dart';

    expect(isValidTestPaths(mainPath), isTrue);
    expect(isValidTestPaths('--target=$mainPath'), isTrue);
    expect(isValidTestPaths('--target=$mainPath --driver=$testPath'), isTrue);
    expect(isValidTestPaths('--driver=$testPath --target=$mainPath '), isTrue);
    expect(isValidTestPaths('--driver $testPath --target $mainPath '), isTrue);

    if (!isCI()) {
      expect(isValidTestPaths(bogusPath), isFalse);
      expect(isValidTestPaths('--target=$bogusPath'), isFalse);
      expect(
          isValidTestPaths('--target=$bogusPath --driver=$mainPath'), isFalse);
      expect(
          isValidTestPaths('--target=$mainPath --driver=$bogusPath'), isFalse);
    }
  });

  test('validate config file', () async {
    final Screens screens = Screens();
    await screens.init();
    final Config config = Config(configPath: 'test/screenshots_test.yaml');
    final daemonClient = DaemonClient();
    await daemonClient.start;
    // for this test change directory
    final origDir = Directory.current;
    Directory.current = 'example';
    expect(
        await isValidConfig(
          config,
          screens,
          await daemonClient.devices,
          await daemonClient.emulators,
        ),
        true);
    // allow other tests to continue
    Directory.current = origDir;
  }, skip: isCI());

  test('clear all destination directories on init', () async {
    final Screens screens = Screens();
    await screens.init();
    final config = Config(configStr: screenshotsYaml);
    await fastlane.clearFastlaneDirs(config, screens, RunMode.normal);
  }, skip: isCI());

  test('check if frame is needed', () {
    final config = Config(configStr: screenshotsYaml);

    expect(config.isFrameRequired('iPhone X', null), true);
    expect(config.isFrameRequired('iPhone 7 Plus', null), false);
    expect(config.isFrameRequired('Nexus 5X', null), true);
    expect(config.isFrameRequired('iPhone 5c', null), false);
    final unknownDevice = 'unknown';
    expect(() => config.isFrameRequired('unknown', null),
        throwsA('Error: device \'$unknownDevice\' not found'));
  });
}
