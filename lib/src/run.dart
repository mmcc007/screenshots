import 'dart:async';
import 'dart:io';

import 'config.dart';
import 'daemon_client.dart';
import 'fastlane.dart' as fastlane;
import 'globals.dart';
import 'image_processor.dart';
import 'resources.dart' as resources;
import 'screens.dart';
import 'utils.dart' as utils;

/// Capture screenshots, process, and load into fastlane according to config file.
///
/// For each locale and device or emulator/simulator:
///
/// 1. If not a real device, start the emulator/simulator for current locale.
/// 2. Run each integration test and capture the screenshots.
/// 3. Process the screenshots including adding a frame if required.
/// 4. Move processed screenshots to fastlane destination for upload to stores.
/// 5. If not a real device, stop emulator/simulator.
Future<void> run(
    [String configPath = kConfigFileName, String _runMode = 'normal']) async {
  final runMode = utils.getRunModeEnum(_runMode);

  final screens = Screens();
  await screens.init();

  // start flutter daemon
  print('Starting flutter daemon...');
  final daemonClient = DaemonClient();
  await daemonClient.start;
  // get all attached devices and running emulators/simulators
  final devices = await daemonClient.devices;
  // get all available unstarted android emulators
  // note: unstarted simulators are not properly included in this list
  //       so have to be handled separately
  final emulators = await daemonClient.emulators;

  final config = Config(configPath: configPath);
  // validate config file
  // ignore: invalid_use_of_visible_for_testing_member
  await config.validate(screens, devices, emulators);
  final configInfo = config.configInfo;

  // init
  final stagingDir = configInfo['staging'];
  await Directory(stagingDir + '/test').create(recursive: true);
  await resources.unpackScripts(stagingDir);
  await fastlane.clearFastlaneDirs(configInfo, screens, runMode);

  // run integration tests in each real device (or emulator/simulator) for
  // each locale and process screenshots
  await runTestsOnAll(
      daemonClient, devices, emulators, config, screens, runMode);
  // shutdown daemon
  await daemonClient.stop;

  print('\n\nScreen images are available in:');
  print('  ios/fastlane/screenshots');
  print('  android/fastlane/metadata/android');
  print('for upload to both Apple and Google consoles.');
  print('\nFor uploading and other automation options see:');
  print('  https://pub.dartlang.org/packages/fledge');
  print('\nscreenshots completed successfully.');
}

/// Run the screenshot integration tests on current device, emulator or simulator.
///
/// Each test is expected to generate a sequential number of screenshots.
/// (to match order of appearance in Apple and Google stores)
///
/// Assumes the integration tests capture the screen shots into a known directory using
/// provided [capture_screen.screenshot()].
Future runTestsOnAll(DaemonClient daemonClient, List devices, List emulators,
    Config config, Screens screens, RunMode runMode) async {
  final configInfo = config.configInfo;
  final locales = configInfo['locales'];
  final stagingDir = configInfo['staging'];
  final testPaths = configInfo['tests'];
  final configDeviceNames = utils.getAllConfiguredDeviceNames(configInfo);
  final imageProcessor = ImageProcessor(screens, configInfo);

  if (runMode != RunMode.normal) {
    final recordingDir = configInfo['recording'];
    recordingDir == null
        ? throw 'Error: \'recording\' dir is not specified in screenshots.yaml'
        : null;
    runMode == RunMode.comparison && (!(await utils.isRecorded(recordingDir)))
        ? throw 'Error: a recording must be run before a comparison'
        : null;
  }

  for (final configDeviceName in configDeviceNames) {
    // look for matching device first
    final device = _findDevice(devices, emulators, configDeviceName);

    String deviceId;
    Map emulator;
    Map simulator;
    bool pendingLocaleChange = false;
    if (device != null) {
      deviceId = device['id'];
    } else {
      // if no matching device, look for matching android emulator
      // and start it
      emulator = utils.findEmulator(emulators, configDeviceName);
      if (emulator != null) {
        print('Starting $configDeviceName...');
        deviceId =
            await _startEmulator(daemonClient, emulator['id'], stagingDir);
      } else {
        // if no matching android emulator, look for matching ios simulator
        // and start it
        simulator = utils.getHighestIosSimulator(
            utils.getIosSimulators(), configDeviceName);
        deviceId = simulator['udid'];
        // check if current device is pending a locale change
        if (locales[0] == utils.iosSimulatorLocale(deviceId)) {
          print('Starting $configDeviceName...');
          startSimulator(deviceId);
        } else {
          pendingLocaleChange = true;
          print('Not starting $configDeviceName due to pending locale change');
        }
      }
    }
    assert(deviceId != null);

    // Check for a running android device or emulator
    bool isRunningAndroidDeviceOrEmulator(Map device, Map emulator) {
      return (device != null && device['platform'] != 'ios') ||
          (device == null && emulator != null);
    }

    // save original locale for reverting later if necessary
    String origLocale;
    if (isRunningAndroidDeviceOrEmulator(device, emulator)) {
      origLocale = utils.androidDeviceLocale(deviceId);
    }

    for (final locale in locales) {
      // set locale if android device or emulator
      if (isRunningAndroidDeviceOrEmulator(device, emulator)) {
        await setAndroidLocale(deviceId, locale, configDeviceName);
      }
      // set locale if ios simulator
      if ((device != null &&
          device['platform'] == 'ios' &&
          device['emulator'])) {
        // an already running simulator
        await setSimulatorLocale(
            deviceId, configDeviceName, locale, stagingDir);
      } else {
        if (device == null && simulator != null) {
          if (pendingLocaleChange) {
            // a non-running simulator
            await setSimulatorLocale(
                deviceId, configDeviceName, locale, stagingDir,
                running: false);
          } else {
            // a running simulator
            await setSimulatorLocale(
                deviceId, configDeviceName, locale, stagingDir);
          }
        }
      }
      // issue locale warning if ios device
      if ((device != null &&
          device['platform'] == 'ios' &&
          !device['emulator'])) {
        // a running ios device
        print('Warning: the locale of an ios device cannot be changed.');
      }
      final deviceType = getDeviceType(configInfo, configDeviceName);

      // store env for later use by tests
      // ignore: invalid_use_of_visible_for_testing_member
      await config.storeEnv(screens, configDeviceName, locale,
          utils.getStringFromEnum(deviceType));

      // run tests
      for (final testPath in testPaths) {
        print(
            'Running $testPath on \'$configDeviceName\' in locale $locale...');
        await utils.streamCmd('flutter', ['-d', deviceId, 'drive', testPath]);

        // process screenshots
        await imageProcessor.process(
            deviceType, configDeviceName, locale, runMode);
      }
    }

    // if an emulator was started, revert locale if necessary and shut it down
    if (emulator != null) {
      await setAndroidLocale(deviceId, origLocale, configDeviceName);
      await shutdownAndroidEmulator(daemonClient, deviceId);
    }
    if (simulator != null) {
      // todo: revert locale
      shutdownSimulator(deviceId);
    }
  }
}

void shutdownSimulator(String deviceId) {
  cmd('xcrun', ['simctl', 'shutdown', deviceId]);
}

void startSimulator(String deviceId) {
  cmd('xcrun', ['simctl', 'boot', deviceId]);
}

/// Start android emulator and return device id.
Future<String> _startEmulator(
    DaemonClient daemonClient, String emulatorId, stagingDir) async {
  if (Platform.environment['CI'] == 'true') {
    // testing on CI/CD requires starting emulator in a specific way
    await _startAndroidEmulatorOnCI(emulatorId, stagingDir);
    return utils.findAndroidDeviceId(emulatorId);
  } else {
    // testing locally, so start emulator in normal way
    return await daemonClient.launchEmulator(emulatorId);
  }
}

/// Find a real device or running emulator/simulator for [deviceName].
Map _findDevice(List devices, List emulators, String deviceName) {
  final device = devices.firstWhere((device) {
    if (device['platform'] == 'ios') {
      if (device['emulator']) {
        // running ios simulator
        return device['name'] == deviceName;
      } else {
        // real ios device
        return device['model'].contains(deviceName);
      }
    } else {
      if (device['emulator']) {
        // running android emulator
        return _findDeviceEmulator(emulators, device['id'])['name'] ==
            deviceName;
      } else {
        // real android device
        return device['name'] == deviceName;
      }
    }
  }, orElse: () => null);
  return device;
}

/// Set the locale for a running simulator.
Future setSimulatorLocale(
    String deviceId, String deviceName, String testLocale, stagingDir,
    {bool running = true}) async {
  // a running simulator
  final deviceLocale = utils.iosSimulatorLocale(deviceId);
//  print('simulator locale=$deviceLocale');
  if (testLocale != deviceLocale) {
    if (running) shutdownSimulator(deviceId);
    print(
        'Changing locale from $deviceLocale to $testLocale on \'$deviceName\'...');
    await _changeSimulatorLocale(stagingDir, deviceId, testLocale);
    startSimulator(deviceId);
  }
}

/// Set the locale for a real android device or a running emulator.
Future<void> setAndroidLocale(String deviceId, testLocale, deviceName) async {
  // a running android device or emulator
  final deviceLocale = utils.androidDeviceLocale(deviceId);
//  print('android device or emulator locale=$deviceLocale');
  if (deviceLocale != null &&
      deviceLocale != '' &&
      deviceLocale != testLocale) {
    //          daemonClient.verbose = true;
    print(
        'Changing locale from $deviceLocale to $testLocale on \'$deviceName\'...');
    changeAndroidLocale(deviceId, deviceLocale, testLocale);
    //          daemonClient.verbose = false;
    await utils.waitAndroidLocaleChange(deviceId, testLocale);
  }
}

/// Change local of real android device or running emulator.
void changeAndroidLocale(
    String deviceId, String deviceLocale, String testLocale) {
  if (cmd('adb', ['root'], '.', true) ==
      'adbd cannot run as root in production builds\n') {
    stdout.write(
        'Warning: locale will not be changed. Running in locale \'$deviceLocale\'.\n');
    stdout.write(
        'To change locale you must use a non-production emulator (one that does not depend on Play Store). See:\n');
    stdout.write(
        '    https://stackoverflow.com/questions/43923996/adb-root-is-not-working-on-emulator/45668555#45668555 for details.\n');
  }
  _flutterDriverBugWarning();
  // adb shell "setprop persist.sys.locale fr-CA; setprop ctl.restart zygote"
  cmd('adb', [
    '-s',
    deviceId,
    'shell',
    'setprop',
    'persist.sys.locale',
    testLocale,
    ';',
    'setprop',
    'ctl.restart',
    'zygote'
  ]);
}

/// Change locale of non-running simulator.
Future _changeSimulatorLocale(
    String stagingDir, String name, String testLocale) async {
  _flutterDriverBugWarning();
  await utils.streamCmd('$stagingDir/resources/script/simulator-controller',
      [name, 'locale', testLocale]);
}

/// Shutdown an android emulator.
Future<String> shutdownAndroidEmulator(
    DaemonClient daemonClient, String deviceId) async {
  cmd('adb', ['-s', deviceId, 'emu', 'kill'], '.', true);
//  await waitAndroidEmulatorShutdown(deviceId);
  final device = await daemonClient.waitForEvent(Event.deviceRemoved);
  if (device['id'] != deviceId) {
    throw 'Error: device id \'$deviceId\' not shutdown';
  }
  return device['id'];
}

void _flutterDriverBugWarning() {
  stdout.write(
      '\nWarning: running tests in a non-default locale will cause test to hang due to a bug in Flutter Driver (not related to \'screenshots\'). Modify your screenshots.yaml to use only the default locale for your location. For details of bug see comment at https://github.com/flutter/flutter/issues/27785#issue-408955077. Give comment a thumbs-up to get it fixed!\n\n');
}

/// Start android emulator in a CI environment.
Future _startAndroidEmulatorOnCI(String emulatorId, String stagingDir) async {
  // testing on CI/CD requires starting emulator in a specific way
  final androidHome = Platform.environment['ANDROID_HOME'];
  await utils.streamCmd(
      '$androidHome/emulator/emulator',
      [
        '-avd',
        emulatorId,
        '-no-audio',
        '-no-window',
        '-no-snapshot',
        '-gpu',
        'swiftshader',
      ],
      '.',
      ProcessStartMode.detached);
  // wait for emulator to start
  await utils
      .streamCmd('$stagingDir/resources/script/android-wait-for-emulator', []);
}

/// Find the emulator info of a running device.
Map _findDeviceEmulator(List emulators, String deviceId) {
  return emulators.firstWhere(
      (emulator) => emulator['id'] == utils.getAndroidEmulatorId(deviceId),
      orElse: () => null);
}

/// Get device type from config info
DeviceType getDeviceType(Map configInfo, String deviceName) {
  final androidDeviceNames = configInfo['devices']['android']?.keys ?? [];
  final iosDeviceNames = configInfo['devices']['ios']?.keys ?? [];
  // search in both
  DeviceType deviceType =
      androidDeviceNames.contains(deviceName) ? DeviceType.android : null;
  deviceType = deviceType == null
      ? iosDeviceNames.contains(deviceName) ? DeviceType.ios : null
      : deviceType;
  return deviceType;
}

/// Execute command [cmd] with arguments [arguments] in a separate process
/// and return stdout as string.
///
/// If [silent] is false, output to stdout.
String cmd(String cmd, List<String> arguments,
    [String workingDir = '.', bool silent = false]) {
//  print(
//      'cmd=\'$cmd ${arguments.join(" ")}\', workingDir=$workingDir, silent=$silent');
  final result = Process.runSync(cmd, arguments, workingDirectory: workingDir);
  if (!silent) stdout.write(result.stdout);
  if (result.exitCode != 0) {
    stderr.write(result.stderr);
    throw 'command failed: exitcode=${result.exitCode}, cmd=\'$cmd ${arguments.join(" ")}\', workingDir=$workingDir, silent=$silent';
  }
  // return stdout
  return result.stdout;
}
