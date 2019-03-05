import 'dart:io';

import 'package:screenshots/config.dart';
import 'package:screenshots/screens.dart';
import 'package:screenshots/image_magick.dart';
import 'package:screenshots/resources.dart';
import 'package:screenshots/screenshots.dart';
import 'package:screenshots/utils.dart';
import 'package:test/test.dart';
import 'package:screenshots/fastlane.dart' as fastlane;

void main() {
  test('screen info for device: Nexus 5X', () async {
    final expected = {
      'resources': {
        'statusbar': 'resources/android/1080/statusbar.png',
        'navbar': 'resources/android/1080/navbar.png',
        'frame': 'resources/android/phones/Nexus_5X.png'
      },
      'destName': 'phone',
      'resize': '80%',
      'devices': ['Nexus 5X'],
      'offset': '-4-9',
      'size': '1080x1920'
    };
    final Screens screens = Screens();
    await Screens().init();
    Map screen = screens.screenProps('Nexus 5X');
    expect(screen, expected);
  });

  test('screen info for device: iPhone X', () async {
    final expected = {
      'resources': {'frame': 'resources/ios/phones/Apple iPhone X Silver.png'},
      'resize': '75%',
      'devices': ['iPhone X'],
      'offset': '-0-0',
      'size': '2436×1125'
    };
    final Screens screens = Screens();
    await Screens().init();
    Map screen = screens.screenProps('iPhone X');
    expect(screen, expected);
  });

  test('config info for app', () {
    final expected = {
      'tests': ['test_driver/main.dart'],
      'locales': ['en-US'],
      'frame': true,
      'devices': {
        'android': ['Nexus 5X'],
        'ios': ['iPhone 7 Plus']
      },
      'staging': '/tmp/screenshots'
    };

    final Config config = Config('test/test_config.yaml');
    Map appConfig = config.config;
    expect(appConfig, expected);
  });

  test('overlay statusbar', () async {
    final Screens screens = Screens();
    await screens.init();
    Map screen = screens.screenProps('Nexus 6P');
    final Config config = Config('test/test_config.yaml');
    Map appConfig = config.config;

//    final screenshotPath = '/tmp/screenshots/test/0.png';
//    final statusbarResourcePath = 'resources/android/1080/statusbar.png';
//    final statusbarPath = '/tmp/statusbar.png';
//    final screenshotStatusbarPath = '/tmp/screenshots/test/0.png';

//    final statusbarResourcePath = screen['statusbar'];

    final Map resources = screen['resources'];
    await unpackImages(resources, '/tmp/screenshots');

    final statusbarPath = '${appConfig['staging']}/${resources['statusbar']}';
    final screenshotPath = '${appConfig['staging']}/test/0.png';
//    final screenshotStatusbarPath =
//        '${appConfig['staging']}/test/statusbar-0.png';

    final options = {
      'screenshotPath': screenshotPath,
//      'statusbarResourcePath': statusbarResourcePath,
      'statusbarPath': statusbarPath,
//      'screenshotStatusbarPath': screenshotStatusbarPath,
    };
    print('options=$options');
    await imagemagick('overlay', options);
  });

  test('unpack screen resource images', () async {
    final Screens screens = Screens();
    await screens.init();
//    Map screen = screens.screen(screensInfo, 'Nexus 5X');
    Map screen = screens.screenProps('iPhone 7 Plus');
    final Config config = Config('test/test_config.yaml');
    Map appConfig = config.config;

    final staging = appConfig['staging'];

    final Map screenResources = screen['resources'];
//    print('resources=$resources');
//    List screenResources = [];
//    resources.forEach((k, resource) {
//      screenResources.add(resource);
//    });
    print('screenResources=$screenResources');

    await unpackImages(screenResources, staging);
  });

  test('append navbar', () async {
    final Screens screens = Screens();
    await screens.init();
    Map screen = screens.screenProps('Nexus 6P');
    final Config config = Config('test/test_config.yaml');
    Map appConfig = config.config;

    final Map resources = screen['resources'];
    await unpackImages(resources, '/tmp/screenshots');

    final screenshotNavbarPath =
        '${appConfig['staging']}/${resources['navbar']}';
    final screenshotPath = '${appConfig['staging']}/test/0.png';

    final options = {
      'screenshotPath': screenshotPath,
      'screenshotNavbarPath': screenshotNavbarPath,
    };
    print('options=$options');
    await imagemagick('append', options);
  });

  test('frame screenshot', () async {
    final Screens screens = Screens();
    await screens.init();
    Map screen = screens.screenProps('Nexus 6P');
    final Config config = Config('test/test_config.yaml');
    Map appConfig = config.config;

    final Map resources = screen['resources'];
    await unpackImages(resources, '/tmp/screenshots');

    final framePath = appConfig['staging'] + '/' + resources['frame'];
    final size = screen['size'];
    final resize = screen['resize'];
    final offset = screen['offset'];
    final screenshotPath = '${appConfig['staging']}/test/0.png';

    final options = {
      'framePath': framePath,
      'size': size,
      'resize': resize,
      'offset': offset,
      'screenshotPath': screenshotPath,
    };
    print('options=$options');
    await imagemagick('frame', options);
  });

  test('parse xcrun simctl list devices', () {
    Map _simulators = simulatorsx();
    print('simulators=$_simulators');

    print('iPhone X info: ' + _simulators['iPhone X'].toString());

//     print('first match:' + regExp.firstMatch(screens).toString());
  });

  test('parse json xcrun simctl list devices', () {
    Map devicesInfo = getIosDevices();

//    Map _simulators = simulators2();
//    print('simulators=$_simulators');
//
    print('iPhone 7 Plus info: ' + devicesInfo['iPhone 7 Plus'].toString());
    print('iPhone X info: ' + devicesInfo['iPhone X'].toString());
//     print('first match:' + regExp.firstMatch(screens).toString());
  });

  test('read resource and write to path', () async {
//    print(await sampleTxt());
//    print(await sampleImage());
////    print(await image('resources/sample.png'));
//    writeImage(await sampleImage(), '/tmp/sample.png');
    final resources = [
      'resources/android/1080/statusbar.png',
      'resources/android/1080/navbar.png',
      'resources/android/phones/Nexus_5X.png'
    ];
    final dest = '/tmp';
    for (String resource in resources)
      writeImage(await readResourceImage(resource), '$dest/$resource');
  });

  test('unpack images', () async {
    final resources = {
      'A': 'resources/android/1080/statusbar.png',
      'B': 'resources/android/1080/navbar.png',
      'C': 'resources/android/phones/Nexus_5X.png'
    };
    final dest = '/tmp';
    await unpackImages(resources, dest);
  });

  test('unpack script', () async {
    await unpackScript('/tmp', 'resources/script/android-wait-for-emulator');
  });

  test('add prefix to files in directory', () async {
    await prefixFilesInDir('/tmp/screenshots/test', 'my_prefix');
  });

  test('validate config file', () async {
    final Screens screens = Screens();
    await screens.init();
    final Config config = Config('test/test_config.yaml');
    expect(await config.validate(screens), true);
  });

  test('config guide', () async {
    final Screens screens = Screens();
    await screens.init();
    final Config config = Config('test/test_config.yaml');
    config.configGuide(screens);
  });

  test('rooted emulator', () {
    final result = cmd('adb', ['root']);
    print(result);
    expect(result, 'adbd cannot run as root in production builds\n');
  });

  test('map device name to emulator', () {
    final _emulators = emulators();
    print(_emulators);
    final emulator =
        _emulators.firstWhere((emulator) => emulator.contains('Nexus_5X'));
    expect(emulator, 'Nexus_5X_API_27');
  });

  test('change android locale', () {
//    emulator('Nexus 6P', true, '/tmp/screenshots', 'fr-CA');
    emulator('Nexus 6P', true, '/tmp/screenshots', 'en-US');
  });

  test('move files', () async {
    final fileName = 'filename';
    final srcDir = '/tmp/tmp1/multiple/levels/deep';
    final dstDir = '/tmp/tmp2/more/levels/deep';

    await File('$srcDir/$fileName').create(recursive: true);
    moveFiles(srcDir, dstDir);
    expect(await File(dstDir + '/' + fileName).exists(), true);
  });

  test('start simulator', () {
    simulator('iPhone X', true, '/tmp/screenshots');
//    simulator('iPhone X', true, '/tmp/screenshots', 'fr-CA');
  });

  test('stream output from command', () async {
    await streamCmd('ls', ['-la']);
    stdout.write('finished\n\n');
//    print('finished\n');
//    await stdout.flush();
//    await stdout.close();
//    await stdout.done;
    await streamCmd('ls', ['-33']);
  });

  test('clear all destination directories on init', () async {
    final Screens screens = Screens();
    await screens.init();
    final Config config = Config('test/test_config.yaml');
    await fastlane.clearFastlaneDirs(config.config, screens);
  });

  test('start emulator on travis', () async {
    final androidHome = Platform.environment['ANDROID_HOME'];
    final emulatorName = 'Nexus_6P_API_27';
    await streamCmd(
        '$androidHome/emulator/emulator',
        [
          '-avd',
          emulatorName,
          '-no-audio',
          '-no-window',
          '-no-snapshot',
          '-gpu',
          'swiftshader',
        ],
        ProcessStartMode.detached);
  });

  test('check for no running emulators, simulators or devices', () {
    if (cmd('flutter', ['devices'], '.', true).contains('No devices detected.'))
      print('nothing running');
    else
      print('something running');
  });
}
