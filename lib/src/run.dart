import 'dart:async';
import 'dart:io';

import 'package:intl/intl.dart';

import 'archive.dart';
import 'config.dart';
import 'daemon_client.dart';
import 'fastlane.dart' as fastlane;
import 'globals.dart';
import 'image_processor.dart';
import 'orientation.dart' as orient;
import 'resources.dart' as resources;
import 'screens.dart';
import 'utils.dart' as utils;
import 'validate.dart';

/// Capture screenshots, process, and load into fastlane according to config file.
///
/// For each locale and device or emulator/simulator:
///
/// 1. If not a real device, start the emulator/simulator for current locale.
/// 2. Run each integration test and capture the screenshots.
/// 3. Process the screenshots including adding a frame if required.
/// 4. Move processed screenshots to fastlane destination for upload to stores.
/// 5. If not a real device, stop emulator/simulator.
Future<bool> run(
    [String configPath = kConfigFileName,
    String configStr,
    String _runMode = 'normal',
    String flavor = kNoFlavor]) async {
  final runMode = utils.getRunModeEnum(_runMode);

  final screens = Screens();
  await screens.init();

  // start flutter daemon
  print('Starting flutter daemon...');
  final daemonClient = DaemonClient();
  daemonClient.verbose = true;
  await daemonClient.start;
  // get all attached devices and running emulators/simulators
  final devices = await daemonClient.devices;
  // get all available unstarted android emulators
  // note: unstarted simulators are not properly included in this list
  //       so have to be handled separately
  final emulators = (await daemonClient.emulators);
  emulators.sort(utils.emulatorComparison);

  final config = Config(configPath: configPath, configStr: configStr);
  // validate config file
  await validate(config, screens, devices, emulators);
  final configInfo = config.configInfo;

  // init
  final stagingDir = configInfo['staging'];
  await Directory(stagingDir + '/$kTestScreenshotsDir').create(recursive: true);
  if (!Platform.isWindows) await resources.unpackScripts(stagingDir);
  Archive archive = Archive(configInfo['archive']);
  if (runMode == RunMode.archive) {
    print('Archiving screenshots to ${archive.archiveDirPrefix}...');
  } else {
    await fastlane.clearFastlaneDirs(configInfo, screens, runMode);
  }
  // run integration tests in each real device (or emulator/simulator) for
  // each locale and process screenshots
  await runTestsOnAll(daemonClient, devices, emulators, config, screens,
      runMode, archive, flavor);
  // shutdown daemon
  await daemonClient.stop;

  print('\n\nScreen images are available in:');
  if (runMode == RunMode.recording) {
    final recordingDir = configInfo['recording'];
    printScreenshotDirs(configInfo, recordingDir);
  } else {
    if (runMode == RunMode.archive) {
      print('  ${archive.archiveDirPrefix}');
    } else {
      printScreenshotDirs(configInfo, null);
      final isIosActive = isRunTypeActive(configInfo, DeviceType.ios);
      final isAndroidActive = isRunTypeActive(configInfo, DeviceType.android);
      if (isIosActive && isAndroidActive) {
        print('for upload to both Apple and Google consoles.');
      }
      if (isIosActive && !isAndroidActive) {
        print('for upload to Apple console.');
      }
      if (!isIosActive && isAndroidActive) {
        print('for upload to Google console.');
      }
      print('\nFor uploading and other automation options see:');
      print('  https://pub.dartlang.org/packages/fledge');
    }
  }
  print('\nscreenshots completed successfully.');
  return true;
}

void printScreenshotDirs(Map configInfo, String dirPrefix) {
  final prefix = dirPrefix == null ? '' : '${dirPrefix}/';
  if (isRunTypeActive(configInfo, DeviceType.ios)) {
    print('  ${prefix}ios/fastlane/screenshots');
  }
  if (isRunTypeActive(configInfo, DeviceType.android)) {
    print('  ${prefix}android/fastlane/metadata/android');
  }
}

/// Run the screenshot integration tests on current device, emulator or simulator.
///
/// Each test is expected to generate a sequential number of screenshots.
/// (to match order of appearance in Apple and Google stores)
///
/// Assumes the integration tests capture the screen shots into a known directory using
/// provided [capture_screen.screenshot()].
Future runTestsOnAll(
    DaemonClient daemonClient,
    List devices,
    List emulators,
    Config config,
    Screens screens,
    RunMode runMode,
    Archive archive,
    String flavor) async {
  final configInfo = config.configInfo;
  final locales = configInfo['locales'];
  final stagingDir = configInfo['staging'];
  final testPaths = configInfo['tests'];
  final configDeviceNames = utils.getAllConfiguredDeviceNames(configInfo);
  final imageProcessor = ImageProcessor(screens, configInfo);

  final recordingDir = configInfo['recording'];
  final archiveDir = configInfo['archive'];
  switch (runMode) {
    case RunMode.normal:
      break;
    case RunMode.recording:
      recordingDir == null
          ? throw 'Error: \'recording\' dir is not specified in screenshots.yaml'
          : null;
      break;
    case RunMode.comparison:
      runMode == RunMode.comparison && (!(await utils.isRecorded(recordingDir)))
          ? throw 'Error: a recording must be run before a comparison'
          : null;
      break;
    case RunMode.archive:
      archiveDir == null
          ? throw 'Error: \'archive\' dir is not specified in screenshots.yaml'
          : null;
      break;
  }

  for (final configDeviceName in configDeviceNames) {
    // look for matching device first
    final device = findDevice(devices, emulators, configDeviceName);

    String deviceId;
    Map emulator;
    Map simulator;
    bool pendingIosLocaleChangeAtStart = false;
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
        if (Intl.canonicalizedLocale(locales[0]) ==
            Intl.canonicalizedLocale(utils.getIosSimulatorLocale(deviceId))) {
          print('Starting $configDeviceName...');
          await startSimulator(daemonClient, deviceId);
        } else {
          pendingIosLocaleChangeAtStart = true;
//          print(
//              'Postponing \'$configDeviceName\' startup due to pending locale change');
        }
      }
    }
    deviceId == null
        ? throw 'Error: device \'$configDeviceName\' not found'
        : null;

    final deviceType = getDeviceType(configInfo, configDeviceName);
    // if device is real ios or android, cannot change locale
    if (device != null && !device['emulator']) {
      final defaultLocale = 'en_US'; // todo: need actual locale of real device
      print('Warning: the locale of a real device cannot be changed.');
      await runProcessTests(
          config,
          screens,
          configDeviceName,
          defaultLocale,
          deviceType,
          testPaths,
          deviceId,
          imageProcessor,
          runMode,
          archive,
          'unknown',
          flavor);
    } else {
      // Function to check for a running android device or emulator
      bool isRunningAndroidDeviceOrEmulator(Map device, Map emulator) {
        return (device != null && device['platform'] != 'ios') ||
            (device == null && emulator != null);
      }

      // save original android locale for reverting later if necessary
      String origAndroidLocale;
      if (isRunningAndroidDeviceOrEmulator(device, emulator)) {
        origAndroidLocale = utils.getAndroidDeviceLocale(deviceId);
      }

      // Function to check for a running ios device or simulator.
      bool isRunningIosDeviceOrSimulator(Map device, Map emulator) {
        return (device != null && device['platform'] == 'ios') ||
            (device == null && simulator != null);
      }

      // save original ios locale for reverting later if necessary
      String origIosLocale;
      if (isRunningIosDeviceOrSimulator(device, emulator)) {
        origIosLocale = utils.getIosSimulatorLocale(deviceId);
      }

      for (final locale in locales) {
        // set locale if android device or emulator
        if (isRunningAndroidDeviceOrEmulator(device, emulator)) {
          await setEmulatorLocale(deviceId, locale, configDeviceName);
        }
        // set locale if ios simulator
        if ((device != null &&
                device['platform'] == 'ios' &&
                device['emulator']) ||
            (device == null &&
                simulator != null &&
                !pendingIosLocaleChangeAtStart)) {
          // an already running simulator or a started simulator
          final localeChanged = await setSimulatorLocale(
              deviceId, configDeviceName, locale, stagingDir, daemonClient);
          if (localeChanged) {
            // restart simulator
            print('Restarting \'$configDeviceName\' due to locale change...');
            await shutdownSimulator(deviceId);
            await startSimulator(daemonClient, deviceId);
          }
        }
        if (pendingIosLocaleChangeAtStart) {
          // a non-running simulator
          await setSimulatorLocale(
              deviceId, configDeviceName, locale, stagingDir, daemonClient);
          print('Starting $configDeviceName...');
          await startSimulator(daemonClient, deviceId);
          pendingIosLocaleChangeAtStart = false;
        }

        // Change orientation if required
        final deviceInfo = configInfo['devices']
            [utils.getStringFromEnum(deviceType)][configDeviceName];
        String deviceOrientation;
        deviceInfo != null
            ? deviceOrientation = deviceInfo['orientation']
            : null;
        if (deviceOrientation != null) {
          final orientation = orient.getOrientationEnum(deviceOrientation);
          final currentDevice =
              utils.getDeviceFromId(await daemonClient.devices, deviceId);
          currentDevice == null
              ? throw 'Error: device \'$configDeviceName\' not found in flutter daemon.'
              : null;
          switch (deviceType) {
            case DeviceType.android:
              if (currentDevice['emulator']) {
                orient.changeDeviceOrientation(deviceType, orientation,
                    deviceId: deviceId);
              } else {
                print(
                    'Warning: cannot change orientation of a real android device.');
              }
              break;
            case DeviceType.ios:
              if (currentDevice['emulator']) {
                orient.changeDeviceOrientation(deviceType, orientation,
                    scriptDir: '$stagingDir/resources/script');
              } else {
                print(
                    'Warning: cannot change orientation of a real iOS device.');
              }
              break;
          }
        }

        // run tests and process images
        await runProcessTests(
            config,
            screens,
            configDeviceName,
            locale,
            deviceType,
            testPaths,
            deviceId,
            imageProcessor,
            runMode,
            archive,
            deviceOrientation,
            flavor);
      }

      // if an emulator was started, revert locale if necessary and shut it down
      if (emulator != null) {
        await setEmulatorLocale(deviceId, origAndroidLocale, configDeviceName);
        await shutdownAndroidEmulator(daemonClient, deviceId);
      }
      if (simulator != null) {
        await setSimulatorLocale(deviceId, configDeviceName, origIosLocale,
            stagingDir, daemonClient);
        await shutdownSimulator(deviceId);
      }
    }
  }
}

Future runProcessTests(
    Config config,
    Screens screens,
    configDeviceName,
    String locale,
    DeviceType deviceType,
    testPaths,
    String deviceId,
    ImageProcessor imageProcessor,
    RunMode runMode,
    Archive archive,
    String orientation,
    String flavor) async {
  // store env for later use by tests
  // ignore: invalid_use_of_visible_for_testing_member
  await config.storeEnv(screens, configDeviceName, locale,
      utils.getStringFromEnum(deviceType), orientation);
  for (final testPath in testPaths) {
    if (flavor != null && flavor != kNoFlavor) {
      print(
          'Running $testPath on \'$configDeviceName\' in locale $locale with flavor $flavor ...');
      await utils.streamCmd('flutter',
          ['-d', deviceId, 'drive', '-t', testPath, '--flavor', flavor]);
    } else {
      print('Running $testPath on \'$configDeviceName\' in locale $locale...');
      await utils.streamCmd(
          'flutter', ['-d', deviceId, 'drive']..addAll(testPath.split(" ")));
    }
    // process screenshots
    await imageProcessor.process(
        deviceType, configDeviceName, locale, runMode, archive);
  }
}

Future<void> shutdownSimulator(String deviceId) async {
  utils.cmd('xcrun', ['simctl', 'shutdown', deviceId]);
  // shutdown apparently needs time when restarting
  // see https://github.com/flutter/flutter/issues/10228 for race condition on simulator
  await Future.delayed(Duration(milliseconds: 2000));
}

Future<void> startSimulator(DaemonClient daemonClient, String deviceId) async {
  utils.cmd('xcrun', ['simctl', 'boot', deviceId]);
  await Future.delayed(Duration(milliseconds: 2000));
  await waitForEmulatorToStart(daemonClient, deviceId);
}

/// Start android emulator and return device id.
Future<String> _startEmulator(
    DaemonClient daemonClient, String emulatorId, stagingDir) async {
  if (utils.isCI()) {
    // testing on CI/CD requires starting emulator in a specific way
    await _startAndroidEmulatorOnCI(emulatorId, stagingDir);
    return utils.findAndroidDeviceId(emulatorId);
  } else {
    // testing locally, so start emulator in normal way
    return await daemonClient.launchEmulator(emulatorId);
  }
}

/// Find a real device or running emulator/simulator for [deviceName].
Map findDevice(List devices, List emulators, String deviceName) {
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
      // platform is android
      // check if ephemeral is present
      // note: sometimes a running emulator has device['emulator'] of false
      //       so using ephemeral for now (may not work for real devices)
      final isEphemeral =
          device['ephemeral'] == null ? false : device['ephemeral'];
      if (isEphemeral || device['emulator']) {
        // running android emulator ??
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

/// Set the simulator locale.
/// (Startup managed elsewhere)
/// Returns true of locale changed.
Future<bool> setSimulatorLocale(String deviceId, String deviceName,
    String testLocale, String stagingDir, DaemonClient daemonClient) async {
  // a running simulator
  final deviceLocale = utils.getIosSimulatorLocale(deviceId);
  print('\'$deviceName\' locale: $deviceLocale, test locale: $testLocale');
  bool localeChanged = false;
  if (Intl.canonicalizedLocale(testLocale) !=
      Intl.canonicalizedLocale(deviceLocale)) {
    print(
        'Changing locale from $deviceLocale to $testLocale on \'$deviceName\'...');
    await _changeSimulatorLocale(stagingDir, deviceId, testLocale);
    localeChanged = true;
  }
  return localeChanged;
}

/// Set the locale of a running emulator.
Future<void> setEmulatorLocale(String deviceId, testLocale, deviceName) async {
  final deviceLocale = utils.getAndroidDeviceLocale(deviceId);
  print('\'$deviceName\' locale: $deviceLocale, test locale: $testLocale');
  if (deviceLocale != null &&
      deviceLocale != '' &&
      Intl.canonicalizedLocale(deviceLocale) !=
          Intl.canonicalizedLocale(testLocale)) {
    //          daemonClient.verbose = true;
    print(
        'Changing locale from $deviceLocale to $testLocale on \'$deviceName\'...');
    changeAndroidLocale(deviceId, deviceLocale, testLocale);
    //          daemonClient.verbose = false;
    await utils.waitAndroidLocaleChange(deviceId, testLocale);
    // allow additional time before orientation change
    await Future.delayed(Duration(milliseconds: 5000));
  }
}

/// Change local of real android device or running emulator.
void changeAndroidLocale(
    String deviceId, String deviceLocale, String testLocale) {
  if (utils.cmd('adb', ['-s', deviceId, 'root'], '.', true) ==
      'adbd cannot run as root in production builds\n') {
    stdout.write(
        'Warning: locale will not be changed. Running in locale \'$deviceLocale\'.\n');
    stdout.write(
        'To change locale you must use a non-production emulator (one that does not depend on Play Store). See:\n');
    stdout.write(
        '    https://stackoverflow.com/questions/43923996/adb-root-is-not-working-on-emulator/45668555#45668555 for details.\n');
  }
  // adb shell "setprop persist.sys.locale fr_CA; setprop ctl.restart zygote"
  utils.cmd('adb', [
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
  await utils.streamCmd('$stagingDir/resources/script/simulator-controller',
      [name, 'locale', testLocale]);
}

/// Shutdown an android emulator.
Future<String> shutdownAndroidEmulator(
    DaemonClient daemonClient, String deviceId) async {
  utils.cmd('adb', ['-s', deviceId, 'emu', 'kill'], '.', true);
//  await waitAndroidEmulatorShutdown(deviceId);
  final device = await daemonClient.waitForEvent(EventType.deviceRemoved);
  if (device['id'] != deviceId) {
    throw 'Error: device id \'$deviceId\' not shutdown';
  }
  return device['id'];
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
  final emulatorId = utils.getAndroidEmulatorId(deviceId);
  return emulators.firstWhere((emulator) => emulator['id'] == emulatorId,
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

/// Check Image Magick is installed.
void checkImageMagicInstalled() {
  bool isInstalled = false;
  if (Platform.isWindows) {
    isInstalled = utils.cmd('magick', [], '.', true).isNotEmpty;
  } else {
    isInstalled = utils
        .cmd(
            'sh',
            ['-c', 'which convert && echo convert || echo not installed'],
            '.',
            true)
        .toString()
        .contains('convert');
  }
  if (!isInstalled) {
    stderr.write(
        '#############################################################\n');
    stderr.write("# You have to install ImageMagick to use Screenshots\n");
    stderr.write(
        "# Install it using 'brew update && brew install imagemagick'\n");
    stderr.write("# If you don't have homebrew: goto http://brew.sh\n");
    stderr.write(
        '#############################################################\n');
    exit(1);
  }
}

/// Check for active run type.
/// Runs can only be one of [DeviceType].
isRunTypeActive(Map config, DeviceType runType) {
  final Map devices = config['devices'];
  final deviceType = utils.getStringFromEnum(runType);
  final isActive = devices.keys.contains(deviceType);
  return isActive && devices[deviceType] != null;
}
