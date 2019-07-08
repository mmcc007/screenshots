import 'dart:convert';
import 'dart:io';

import 'package:process/process.dart';
import 'package:screenshots/config.dart';
import 'package:screenshots/daemon_client.dart';
import 'package:screenshots/image_processor.dart';
import 'package:screenshots/screens.dart';
import 'package:screenshots/image_magick.dart';
import 'package:screenshots/resources.dart';
import 'package:screenshots/screenshots.dart';
import 'package:screenshots/utils.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('screen info for device: Nexus 5X', () async {
    final expected = {
      'resources': {
        'statusbar white': 'resources/android/1080/statusbar.png',
        'statusbar': 'resources/android/1080/statusbar.png',
        'navbar': 'resources/android/1080/navbar.png',
        'frame': 'resources/android/phones/Nexus_5X.png',
        'statusbar black': 'resources/android/1080/statusbar.png'
      },
      'destName': 'phone',
      'resize': '80%',
      'devices': ['Nexus 5X'],
      'offset': '-4-9',
      'size': '1080x1920'
    };
    final screens = Screens();
    await screens.init();
    final screen = screens.screenProps('Nexus 5X');
    expect(screen, expected);
  });

  test('screen info for device: iPhone X', () async {
    final expected = {
      'resources': {
        'statusbar white': 'resources/ios/1125/statusbar_white.png',
        'statusbar': 'resources/ios/1125/statusbar_white.png',
        'frame': 'resources/ios/phones/Apple iPhone X Silver.png',
        'statusbar black': 'resources/ios/1125/statusbar_black.png'
      },
      'resize': '87%',
      'devices': ['iPhone X', 'iPhone XS', 'iPhone Xs'],
      'offset': '-0-0',
      'size': '1125x2436'
    };
    final screens = Screens();
    await screens.init();
    final screen = screens.screenProps('iPhone X');
    expect(screen, expected);
  });

  test('overlay statusbar', () async {
    final Screens screens = Screens();
    await screens.init();
    final screen = screens.screenProps('Nexus 6P');
    final Config config = Config('test/screenshots_test.yaml');
    final configInfo = config.configInfo;
    final Map resources = screen['resources'];
    await unpackImages(resources, '/tmp/screenshots');
    final statusbarPath = '${configInfo['staging']}/${resources['statusbar']}';
    final screenshotPath = 'test/resources/0.png';
    final options = {
      'screenshotPath': screenshotPath,
      'statusbarPath': statusbarPath,
    };
    await imagemagick('overlay', options);
  });

  test('unpack screen resource images', () async {
    final Screens screens = Screens();
    await screens.init();
    final screen = screens.screenProps('iPhone 7 Plus');
    final Config config = Config('test/screenshots_test.yaml');
    final configInfo = config.configInfo;
    final staging = configInfo['staging'];
    final Map screenResources = screen['resources'];
    await unpackImages(screenResources, staging);
  });

  test('append navbar', () async {
    final Screens screens = Screens();
    await screens.init();
    final screen = screens.screenProps('Nexus 9');
    final Config config = Config('test/screenshots_test.yaml');
    final configInfo = config.configInfo;
    final Map resources = screen['resources'];
    await unpackImages(resources, '/tmp/screenshots');
    final screenshotNavbarPath =
        '${configInfo['staging']}/${resources['navbar']}';
    final screenshotPath = 'test/resources/nexus_9_0.png';
    final options = {
      'screenshotPath': screenshotPath,
      'screenshotNavbarPath': screenshotNavbarPath,
    };
    await imagemagick('append', options);
  });

  test('frame screenshot', () async {
    final Screens screens = Screens();
    await screens.init();
    final screen = screens.screenProps('Nexus 9');
    final Config config = Config('test/screenshots_test.yaml');
    final configInfo = config.configInfo;
    final Map resources = screen['resources'];
    await unpackImages(resources, '/tmp/screenshots');
    final framePath = configInfo['staging'] + '/' + resources['frame'];
    final size = screen['size'];
    final resize = screen['resize'];
    final offset = screen['offset'];
    final screenshotPath = 'test/resources/nexus_9_0.png';
    final options = {
      'framePath': framePath,
      'size': size,
      'resize': resize,
      'offset': offset,
      'screenshotPath': screenshotPath,
      'backgroundColor': ImageProcessor.kDefaultAndroidBackground,
    };
    await imagemagick('frame', options);
  });

  test('parse json xcrun simctl list devices', () {
    final expected = {
      'iOS 11.2': [
        {
          'state': 'Shutdown',
          'availability': '(available)',
          'name': 'iPhone 7 Plus',
          'udid': '1DD6DBF1-846F-4644-8E97-76175788B9A5'
        }
      ],
      'iOS 11.1': [
        {
          'state': 'Shutdown',
          'availability': '(available)',
          'name': 'iPhone 7 Plus',
          'udid': 'BF17CEF1-A6B7-4689-96A2-CE9C271D5F16'
        }
      ]
    };
    final iosDevices = getIosSimulators();
    final iPhone7Plus = iosDevices['iPhone 7 Plus'];
    expect(iPhone7Plus, expected);
  });

  test('get highest and available version of ios device', () {
    final expected = {
      'state': 'Shutdown',
      'availability': '(available)',
      'name': 'iPhone 7 Plus',
      'udid': '1DD6DBF1-846F-4644-8E97-76175788B9A5'
    };
    final iosDevices = getIosSimulators();
    final deviceName = 'iPhone 7 Plus';
//    final deviceName = 'iPhone 5c';
    final highestDevice = getHighestIosSimulator(iosDevices, deviceName);
    expect(highestDevice, expected);
  });

  test('read resource and write to path', () async {
    final resources = [
      'resources/android/1080/statusbar.png',
      'resources/android/1080/navbar.png',
      'resources/android/phones/Nexus_5X.png'
    ];
    final dest = '/tmp';
    for (String resource in resources) {
      await writeImage(await readResourceImage(resource), '$dest/$resource');
    }
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
    await unpackScript('resources/script/android-wait-for-emulator', '/tmp');
  });

  test('add prefix to files in directory', () async {
    await prefixFilesInDir('/tmp/screenshots/test', 'my_prefix');
  });

  test('config guide', () async {
    final Screens screens = Screens();
    await screens.init();
    final Config config = Config('test/screenshots_test.yaml');
    final daemonClient = DaemonClient();
    await daemonClient.start;
    config.generateConfigGuide(screens, await daemonClient.devices);
  });

  test('rooted emulator', () async {
    final emulatorId = 'Nexus_5X_API_27';
    final stagingDir = '/tmp/tmp';
    await unpackScripts(stagingDir);
    final daemonClient = DaemonClient();
    await daemonClient.start;
    final deviceId = await daemonClient.launchEmulator(emulatorId);
    final result = cmd('adb', ['root'], '.', true);
    expect(result, 'adbd cannot run as root in production builds\n');
    await shutdownAndroidEmulator(deviceId);
  });

  test('get emulator id from device name', () {
    final _emulators = getAvdNames();
    print(_emulators);
    final emulator =
        _emulators.firstWhere((emulator) => emulator.contains('Nexus_5X'));
    expect(emulator, 'Nexus_5X_API_27');
  });

  test('move files', () async {
    final fileName = 'filename';
    final srcDir = '/tmp/tmp1/multiple/levels/deep';
    final dstDir = '/tmp/tmp2/more/levels/deep';

    await File('$srcDir/$fileName').create(recursive: true);
    moveFiles(srcDir, dstDir);
    expect(await File(dstDir + '/' + fileName).exists(), true);
  });

  test('start/stop emulator', () async {
    final expected = {
      'id': 'emulator-5554',
      'name': 'Android SDK built for x86',
      'platform': 'android-x86',
      'emulator': true
    };
    final emulatorName = 'Nexus 6P';
    final emulatorId = 'Nexus_6P_API_28';
    final daemonClient = DaemonClient();
    daemonClient.verbose = true;
    await daemonClient.start;
    final deviceId = await daemonClient.launchEmulator(emulatorId);
    final devices = await daemonClient.devices;
    final startedDevice = (devices, emulatorName) => devices
        .firstWhere((device) => device['emulator'] == true, orElse: () => null);
    expect(startedDevice(devices, emulatorName), expected);
    await shutdownAndroidEmulator(deviceId);
    await daemonClient.waitForEvent(Event.deviceRemoved);
    expect(startedDevice(await daemonClient.devices, emulatorName), null);
  });

  test('change android locale', () async {
    final deviceName = 'Nexus 6P';
    final emulatorId = 'Nexus_6P_API_28';
    final origLocale = 'en-US';
    final newLocale = 'fr-CA';
    final daemonClient = DaemonClient();
    await daemonClient.start;
    daemonClient.verbose = true;
    final deviceId = await daemonClient.launchEmulator(emulatorId);
    print('emulator started');
    changeAndroidLocale(deviceId, deviceName, newLocale);
    // wait for locale to change
    await waitAndroidLocaleChange(deviceId, origLocale, newLocale);
    changeAndroidLocale(deviceId, deviceName, origLocale);
    await waitAndroidLocaleChange(deviceId, newLocale, origLocale);
    await shutdownAndroidEmulator(deviceId);
    await daemonClient.waitForEvent(Event.deviceRemoved);
  }, timeout: Timeout(Duration(seconds: 180)));

  test('start/stop simulator', () async {
    final simulatorName = 'iPhone X';
    final simulatorInfo =
        getHighestIosSimulator(getIosSimulators(), simulatorName);
    // note: daemonClient should get an 'add.device' event after simulator startup
    final deviceId = simulatorInfo['udid'];
    startSimulator(deviceId);
    shutdownSimulator(deviceId);
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
        '.',
        ProcessStartMode.detached);
  });

  test('delete all files with suffix', () async {
    final dirPath = '/tmp/tmp';
    final files = ['image1.png', 'image2.png'];
    final suffix = 'png';

    clearDirectory(dirPath); // creates empty directory

    // create files
    files
        .forEach((fileName) async => await File('$dirPath/$fileName').create());

    // check created
    files.forEach((fileName) async =>
        expect(await File('$dirPath/$fileName').exists(), true));

    // delete files with suffix
    clearFilesWithSuffix(dirPath, suffix);

    // check deleted
    files.forEach((fileName) async =>
        expect(await File('$dirPath/$fileName').exists(), false));
  });

  // reproduce https://github.com/flutter/flutter/issues/27785
  // on android (hangs during test)
  // tested on android emulator in default locale (en-US) and it worked
  // tested on android emulator in automatically changed to locale fr-CA and it hangs
  // tested on android emulator booted in locale fr-CA and it hangs
//  [trace] FlutterDriver: Isolate found with number: 939713595
//  [trace] FlutterDriver: Isolate is paused at start.
//  [trace] FlutterDriver: Attempting to resume isolate
//  [trace] FlutterDriver: Waiting for service extension
//  [info ] FlutterDriver: Connected to Flutter application.
//  00:04 +0: end-to-end test tap on the floating action button; verify counter
//  [warning] FlutterDriver: waitFor message is taking a long time to complete...
//  hangs
  test('change locale on android and test', () async {
    final emulatorId = 'Nexus_6P_API_28';
    final stagingDir = '/tmp/tmp';
//    final locale = 'fr-CA'; // fails
    final testAppDir = 'example';
    final testAppSrcPath = 'test_driver/main.dart';

    // unpack resources
    await unpackScripts(stagingDir);

    final daemonClient = DaemonClient();
    await daemonClient.start;
    // start emulator
    final deviceId = await daemonClient.launchEmulator(emulatorId);

    // run test
    await streamCmd('flutter', ['drive', testAppSrcPath], testAppDir);

    // stop emulator
    await shutdownAndroidEmulator(deviceId);
  },
      timeout:
          Timeout(Duration(seconds: 90))); // increase time to get stacktrace

  test('get android device locale', () async {
    final emulatorId = 'Nexus_6P_API_28';
    final stagingDir = '/tmp/tmp';
    final locale = 'en-US';

    await unpackScripts(stagingDir);
    final daemonClient = DaemonClient();
    await daemonClient.start;
    final deviceId = await daemonClient.launchEmulator(emulatorId);
    final deviceLocale = androidDeviceLocale(deviceId);
    await shutdownAndroidEmulator(deviceId);

    expect(deviceLocale, locale);
  });

  // reproduce https://github.com/flutter/flutter/issues/27785
  // on ios
  // tested on ios device in default locale (en-US) and it worked
  // tested on ios device in manually changed to locale fr-CA and it hangs
  // tested on ios simulator in default locale (en-US) and it worked
  // tested on ios simulator in automatically changed to locale fr-CA and it hangs
  test('change locale on iOS and test', () async {
    final simulatorName = 'iPhone X';
    final stagingDir = '/tmp/tmp';
//    final locale = 'en-US'; // default locale (works)
    final locale = 'fr-CA'; // fails
    final testAppDir = 'example';
    final testAppSrcPath = 'test_driver/main.dart';

    // unpack resources
    await unpackScripts(stagingDir);

    // start simulator
    final simulatorInfo =
        getHighestIosSimulator(getIosSimulators(), simulatorName);
    final daemonClient = DaemonClient();
    await daemonClient.start;
    cmd('xcrun', ['simctl', 'boot', simulatorInfo['udid']]);

    // run test
    await streamCmd('flutter', ['drive', testAppSrcPath], testAppDir);

    // stop simulator
    cmd('xcrun', ['simctl', 'shutdown', simulatorInfo['udid']]);
  },
      timeout:
          Timeout(Duration(minutes: 20))); // increase time to get stacktrace

  test('get ios simulator locale', () async {
    final udId = '03D4FC12-3927-4C8B-A226-17DE34AE9C18';
    var locale = iosSimulatorLocale(udId);
    expect(locale, 'en-US');
  });

  test('get avd from a running emulator', () {
    final deviceId = 'emulator-5554';
    final expected = 'Nexus_6P_API_28';
    final emulatorId = getAndroidEmulatorId(deviceId);
    expect(emulatorId, expected);
  });

//  test('find running emulator with matching avd', () {
//    final avdName = 'Nexus_6P_API_28';
//    final expected = 'emulator-5554';
//    String deviceId = findAndroidDeviceId(avdName);
//    print('device=$deviceId');
//    expect(deviceId, expected);
//  });

//  test('boot android device if not booted', () async {
//    final deviceName = 'Nexus 6P';
//    final avdName = getHighestAVD(deviceName);
//    String deviceId = findAndroidDeviceId(avdName);
//    if (deviceId == null) {
//      // boot emulator
//      print('booting $deviceName...');
//      await streamCmd('flutter', ['emulator', '--launch', avdName]);
//      deviceId = await getBootedAndroidDeviceId(deviceName);
//      print('booted $deviceName on $deviceId');
//      // shutdown
//      print('shutting down $deviceName...');
//      cmd('adb', ['-s', deviceId, 'emu', 'kill']);
//    } else {
//      print('already booted');
//    }
//    expect(deviceId, isNotNull);
//  });

  test('get real devices', () async {
    final daemonClient = DaemonClient();
    await daemonClient.start;
    final devices = await daemonClient.devices;
    final iosDevices = getIosDevices(devices);
    final androidDevices = getAndroidDevices(devices);
    print('iosDevices=$iosDevices');
    print('androidDevices=$androidDevices');
  });

  test('get devices', () {
    final expected = {
      'id': '3b3455019e329e007e67239d9b897148244b5053',
      'name': 'Maurice’s iPhone',
      'platform': 'ios',
      'emulator': false,
      'model': 'iPhone 5c (GSM)'
    };
    String deviceName = 'iPhone 5c';
    Map device = getDevice([expected], deviceName);
    expect(device, expected);
    final isDeviceAttached = (device) => device != null;
    expect(isDeviceAttached(device), true);
    deviceName = 'iPhone X';
    device = getDevice([expected], deviceName);
    expect(device, null);
    expect(isDeviceAttached(device), false);
  });

  test('get device type from config', () {
    final deviceName = 'Nexus 9P';
    final expected = DeviceType.android;
    final config = '''
devices:
  ios:
    iPhone X:
  android:
    $deviceName:
''';

    final configInfo = loadYaml(config);
    DeviceType deviceType = getDeviceType(configInfo, deviceName);
    expect(deviceType, expected);
  });

  test('get adb props, and show diffs', () {
    final expected = {
      'added': {'xxx': 'yyy'},
      'removed': {'wifi.direct.interface': 'p2p-dev-wlan0'},
      'changed': {
        'orig': {'xmpp.auto-presence': 'true'},
        'new': {'xmpp.auto-presence': false}
      }
    };
    final deviceId = 'emulator-5554';
    Map props = getDeviceProps(deviceId);
    final newProps = Map.from(props);
    newProps['xmpp.auto-presence'] = false; //changed
    newProps['xxx'] = 'yyy'; // added
    newProps.remove('wifi.direct.interface'); // removed

    final Map diffs = diffMaps(props, newProps);
    expect(diffs, expected);
  });

  group('ProcessWrapper', () {
    test('works in conjunction with subscribers to stdio streams', () async {
      final expected = 'README.md';
      final delegate = await Process.start('ls', ['-la']);
      final process = ProcessWrapper(delegate);
      final readme = await process.stdout
          .transform<String>(utf8.decoder)
          .transform<String>(const LineSplitter())
          .firstWhere((line) => line.contains(expected));
      expect(readme.contains(expected), isTrue);
    });

    test('scan syslog for string', () async {
      final toLocale = 'en-US';
//      final expected =
//          'ContactsProvider: Locale has changed from [fr_CA] to [en_US]';
//      final expected = RegExp('Locale has changed from');
      final expected = RegExp(
          'ContactsProvider: Locale has changed from .* to [${toLocale.replaceAll('-', '\\-')}]',
          dotAll: true);
//      final expected = 'ActivityManager';
      final daemonClient = DaemonClient();
      await daemonClient.start;
      final emulatorId = 'Nexus_6P_API_28';
      final deviceId = await daemonClient.launchEmulator(emulatorId);
      String actual = await waitSysLogMsg(deviceId, expected);
      expect(actual.contains(expected), isTrue);
      await shutdownAndroidEmulator(deviceId);
    });

    test('reg exp', () {
      final locale = 'fr-CA';
      final line =
          'ContactsProvider: Locale has changed from [en_US] to [${locale.replaceFirst('-', '_')}]';
//      final regExp = RegExp(
//          'ContactsProvider: Locale has changed from .* to [fr_CA]',
//          dotAll: true);
      final regExp = RegExp(
          'ContactsProvider: Locale has changed from .* to \\[${locale.replaceFirst('-', '_')}\\]');
      expect(regExp.stringMatch(line), line);
      expect(regExp.hasMatch(line), true);
    });
  });
}
