import 'dart:async';
//import 'dart:io';

import 'package:intl/intl.dart';
import 'package:tool_base/tool_base.dart' hide Config;
import 'package:tool_mobile/tool_mobile.dart';

import 'archive.dart';
import 'config.dart';
import 'context_runner.dart';
import 'daemon_client.dart';
import 'fastlane.dart' as fastlane;
import 'globals.dart';
import 'image_processor.dart';
import 'orientation.dart' as orient;
import 'resources.dart' as resources;
import 'screens.dart';
import 'utils.dart' as utils;
import 'utils.dart';
import 'validate.dart';
import 'package:path/path.dart' as path;

/// Run screenshots
Future<bool> screenshots(
    {String configPath,
    String configStr,
    String mode = 'normal',
    String flavor = kNoFlavor,
    bool verbose = false}) async {
  // run in context
  if (verbose) {
    Logger verboseLogger = VerboseLogger(
        platform.isWindows ? WindowsStdoutLogger() : StdoutLogger());
    return runInContext<bool>(() async {
      return runScreenshots(
          configPath: configPath,
          configStr: configStr,
          mode: mode,
          flavor: flavor);
    }, overrides: <Type, Generator>{
      Logger: () => verboseLogger,
    });
  } else {
    return runInContext<bool>(() async {
      return runScreenshots(
          configPath: configPath,
          configStr: configStr,
          mode: mode,
          flavor: flavor);
    });
  }
}

/// Capture screenshots, process, and load into fastlane according to config file.
///
/// For each locale and device or emulator/simulator:
///
/// 1. If not a real device, start the emulator/simulator for current locale.
/// 2. Run each integration test and capture the screenshots.
/// 3. Process the screenshots including adding a frame if required.
/// 4. Move processed screenshots to fastlane destination for upload to stores.
/// 5. If not a real device, stop emulator/simulator.
Future<bool> runScreenshots({
  String configPath,
  String configStr,
  String mode = 'normal',
  String flavor = kNoFlavor,
}) async {
  final runMode = utils.getRunModeEnum(mode);

  final screens = Screens();
  await screens.init();

  // start flutter daemon
  Status status;
  status = logger.startProgress('Starting flutter daemon...',
      timeout: Duration(milliseconds: 10000));
  //  daemonClient.verbose = true;
  await daemonClient.start;
  status.stop();

  // get all attached devices and running emulators/simulators
  final devices = await daemonClient.devices;
  // get all available unstarted android emulators
  // note: unstarted simulators are not properly included in this list
  //       so have to be handled separately
  final List<DaemonEmulator> emulators = await daemonClient.emulators;
  emulators.sort(utils.emulatorComparison);

  final config = Config(configPath: configPath, configStr: configStr);
  // validate config file
  if (!await isValidConfig(config, screens, devices, emulators)) {
    return false;
  }

  // init
  await fs
      .directory(path.join(config.stagingDir, kTestScreenshotsDir))
      .create(recursive: true);
  if (!platform.isWindows) await resources.unpackScripts(config.stagingDir);
  Archive archive = Archive(config.archiveDir);
  if (runMode == RunMode.archive) {
    printStatus('Archiving screenshots to ${archive.archiveDirPrefix}...');
  } else {
    await fastlane.clearFastlaneDirs(config, screens, runMode);
  }
  // run integration tests in each real device (or emulator/simulator) for
  // each locale and process screenshots
  await runTestsOnAll(daemonClient, devices, emulators, config, screens,
      runMode, archive, flavor);
  // shutdown daemon
  await daemonClient.stop;

  printStatus('\n\nScreen images are available in:');
  if (runMode == RunMode.recording) {
    printScreenshotDirs(config, config.recordingDir);
  } else {
    if (runMode == RunMode.archive) {
      printStatus('  ${archive.archiveDirPrefix}');
    } else {
      printScreenshotDirs(config, null);
      final isIosActive = config.isRunTypeActive(DeviceType.ios);
      final isAndroidActive = config.isRunTypeActive(DeviceType.android);
      if (isIosActive && isAndroidActive) {
        printStatus('for upload to both Apple and Google consoles.');
      }
      if (isIosActive && !isAndroidActive) {
        printStatus('for upload to Apple console.');
      }
      if (!isIosActive && isAndroidActive) {
        printStatus('for upload to Google console.');
      }
      printStatus('\nFor uploading and other automation options see:');
      printStatus('  https://pub.dartlang.org/packages/fledge');
    }
  }
  printStatus('\nscreenshots completed successfully.');
  return true;
}

void printScreenshotDirs(Config config, String dirPrefix) {
  final prefix = dirPrefix == null ? '' : '${dirPrefix}/';
  if (config.isRunTypeActive(DeviceType.ios)) {
    printStatus('  ${prefix}ios/fastlane/screenshots');
  }
  if (config.isRunTypeActive(DeviceType.android)) {
    printStatus('  ${prefix}android/fastlane/metadata/android');
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
    List<DaemonDevice> runningDevices,
    List<DaemonEmulator> emulators,
    Config config,
    Screens screens,
    RunMode runMode,
    Archive archive,
    String flavor) async {
//  final configInfo = config.configInfo;
  final locales = config.locales;
  final stagingDir = config.stagingDir;
  final testPaths = config.tests;
  final configDeviceNames = config.deviceNames;
  final imageProcessor = ImageProcessor(screens, config);

  final recordingDir = config.recordingDir;
  final archiveDir = config.archiveDir;
  switch (runMode) {
    case RunMode.normal:
      break;
    case RunMode.recording:
      recordingDir == null
          ? throw 'Error: \'recording\' dir is not specified in your screenshots.yaml'
          : null;
      break;
    case RunMode.comparison:
      runMode == RunMode.comparison && (!(await utils.isRecorded(recordingDir)))
          ? throw 'Error: a recording must be run before a comparison'
          : null;
      break;
    case RunMode.archive:
      archiveDir == null
          ? throw 'Error: \'archive\' dir is not specified in your screenshots.yaml'
          : null;
      break;
  }

  for (final configDeviceName in configDeviceNames) {
    // look for matching device first.
    // Note: flutter daemon handles devices and running emulators/simulators as devices.
    final device =
        findRunningDevice(runningDevices, emulators, configDeviceName);

    String deviceId;
    DaemonEmulator emulator;
    Map simulator;
    bool pendingIosLocaleChangeAtStart = false;
    if (device != null) {
      deviceId = device.id;
    } else {
      // if no matching device, look for matching android emulator
      // and start it
      emulator = utils.findEmulator(emulators, configDeviceName);
      if (emulator != null) {
        printStatus('Starting $configDeviceName...');
        deviceId = await _startEmulator(daemonClient, emulator.id, stagingDir);
      } else {
        // if no matching android emulator, look for matching ios simulator
        // and start it
        simulator = utils.getHighestIosSimulator(
            utils.getIosSimulators(), configDeviceName);
        deviceId = simulator['udid'];
        // check if current simulator is pending a locale change
        if (Intl.canonicalizedLocale(locales[0]) ==
            Intl.canonicalizedLocale(utils.getIosSimulatorLocale(deviceId))) {
          printStatus('Starting $configDeviceName...');
          await startSimulator(daemonClient, deviceId);
        } else {
          pendingIosLocaleChangeAtStart = true;
          printTrace(
              'Postponing \'$configDeviceName\' startup due to pending locale change');
        }
      }
    }

    // a device is now found
    // (and running if not ios simulator pending locale change)
    deviceId == null
        ? throw 'Error: device \'$configDeviceName\' not found'
        : Null;

    // set locale and run tests
    final deviceType = getDeviceType(config, configDeviceName);
    if (device != null && !device.emulator) {
      // device is real
      final defaultLocale = 'en_US'; // todo: need actual locale of real device
      printStatus('Warning: the locale of a real device cannot be changed.');
      printStatus('Warning: currently defaulting to locale $defaultLocale.');
      await runProcessTests(
          configDeviceName,
          defaultLocale,
          deviceType,
          testPaths,
          deviceId,
          imageProcessor,
          runMode,
          archive,
          flavor,
          config.configPath);
    } else {
      // device is emulated

      // Function to check for a running android device or emulator.
      bool isRunningAndroidDeviceOrEmulator(
          DaemonDevice device, DaemonEmulator emulator) {
        return (device != null && device.platform != 'ios') ||
            (device == null && emulator != null);
      }

      // save original android locale for reverting later if necessary
      String origAndroidLocale;
      if (isRunningAndroidDeviceOrEmulator(device, emulator)) {
        origAndroidLocale = utils.getAndroidDeviceLocale(deviceId);
      }

      // Function to check for a running ios device or simulator.
      bool isRunningIosDeviceOrSimulator(DaemonDevice device) {
        return (device != null && device.platform == 'ios') ||
            (device == null && simulator != null);
      }

      // save original ios locale for reverting later if necessary
      String origIosLocale;
      if (isRunningIosDeviceOrSimulator(device)) {
        origIosLocale = utils.getIosSimulatorLocale(deviceId);
      }

      for (final locale in locales) {
        // set locale if android device or emulator
        if (isRunningAndroidDeviceOrEmulator(device, emulator)) {
          await setEmulatorLocale(deviceId, locale, configDeviceName);
        }
        // set locale if ios simulator
        if ((device != null && device.platform == 'ios' && device.emulator) ||
            (device == null &&
                simulator != null &&
                !pendingIosLocaleChangeAtStart)) {
          // an already running simulator or a started simulator
          final localeChanged = await setSimulatorLocale(
              deviceId, configDeviceName, locale, stagingDir, daemonClient);
          if (localeChanged) {
            // restart simulator
            printStatus(
                'Restarting \'$configDeviceName\' due to locale change...');
            await shutdownSimulator(deviceId);
            await startSimulator(daemonClient, deviceId);
          }
        }
        if (pendingIosLocaleChangeAtStart) {
          // a non-running simulator
          await setSimulatorLocale(
              deviceId, configDeviceName, locale, stagingDir, daemonClient);
          printStatus('Starting $configDeviceName...');
          await startSimulator(daemonClient, deviceId);
          pendingIosLocaleChangeAtStart = false;
        }

        // Change orientation if required
        final configDevice = config.getDevice(configDeviceName);
        if (configDevice.orientation != null) {
          final currentDevice =
              utils.getDeviceFromId(await daemonClient.devices, deviceId);
          currentDevice == null
              ? throw 'Error: device \'$configDeviceName\' not found in flutter daemon.'
              : null;
          switch (deviceType) {
            case DeviceType.android:
              if (currentDevice.emulator) {
                orient.changeDeviceOrientation(
                    deviceType, configDevice.orientation,
                    deviceId: deviceId);
              } else {
                printStatus(
                    'Warning: cannot change orientation of a real android device.');
              }
              break;
            case DeviceType.ios:
              if (currentDevice.emulator) {
                orient.changeDeviceOrientation(
                    deviceType, configDevice.orientation,
                    scriptDir: '$stagingDir/resources/script');
              } else {
                printStatus(
                    'Warning: cannot change orientation of a real iOS device.');
              }
              break;
          }
        }

        // store env for later use by tests
        // ignore: invalid_use_of_visible_for_testing_member
        await config.storeEnv(screens, configDeviceName, locale, deviceType,
            configDevice.orientation);

        // run tests and process images
        await runProcessTests(
            configDeviceName,
            locale,
            deviceType,
            testPaths,
            deviceId,
            imageProcessor,
            runMode,
            archive,
            flavor,
            config.configPath);
      }

      // if an emulator was started, revert locale if necessary and shut it down
      if (emulator != null) {
        await setEmulatorLocale(deviceId, origAndroidLocale, configDeviceName);
        await shutdownAndroidEmulator(daemonClient, deviceId);
      }
      // if a simulator was started, revert locale if necessary and shut it down
      if (simulator != null) {
        await setSimulatorLocale(deviceId, configDeviceName, origIosLocale,
            stagingDir, daemonClient);
        await shutdownSimulator(deviceId);
      }
    }
  }
}

Future runProcessTests(
  configDeviceName,
  String locale,
  DeviceType deviceType,
  testPaths,
  String deviceId,
  ImageProcessor imageProcessor,
  RunMode runMode,
  Archive archive,
  String flavor,
  String configPath,
) async {
  for (final testPath in testPaths) {
    final environment = {kEnvConfigPath: configPath};
    if (flavor != null && flavor != kNoFlavor) {
      printStatus(
          'Running $testPath on \'$configDeviceName\' in locale $locale with flavor $flavor ...');
      await streamCmd([
        'flutter',
        '-d',
        deviceId,
        'drive',
        '-t',
        testPath,
        '--flavor',
        flavor
      ], environment: environment);
    } else {
      printStatus(
          'Running $testPath on \'$configDeviceName\' in locale $locale...');
      await streamCmd(
          ['flutter', '-d', deviceId, 'drive']..addAll(testPath.split(" ")),
          environment: environment);
    }
    // process screenshots
    await imageProcessor.process(
        deviceType, configDeviceName, locale, runMode, archive);
  }
}

Future<void> shutdownSimulator(String deviceId) async {
  cmd(['xcrun', 'simctl', 'shutdown', deviceId]);
  // shutdown apparently needs time when restarting
  // see https://github.com/flutter/flutter/issues/10228 for race condition on simulator
  await Future.delayed(Duration(milliseconds: 2000));
}

Future<void> startSimulator(DaemonClient daemonClient, String deviceId) async {
  cmd(['xcrun', 'simctl', 'boot', deviceId]);
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
/// Note: flutter daemon handles devices and running emulators/simulators as devices.
DaemonDevice findRunningDevice(List<DaemonDevice> devices,
    List<DaemonEmulator> emulators, String deviceName) {
  return devices.firstWhere((device) {
    // hack for CI testing of old arm emulator
    if (device.id.startsWith('emulator')) {
      /// Find the device name of a running emulator.
      String findDeviceNameOfRunningEmulator(
          List<DaemonEmulator> emulators, String deviceId) {
        final emulatorId = utils.getAndroidEmulatorId(deviceId);
        final emulator = emulators.firstWhere(
            (emulator) => emulator.id == emulatorId,
            orElse: () => null);
        return emulator == null ? null : emulator.name;
      }

      final emulatorName =
          findDeviceNameOfRunningEmulator(emulators, device.id);
      return emulatorName.contains(deviceName);
    }

    if (device.emulator) {
      if (device.platformType == 'android') {
        // running emulator
        return device.emulatorId.replaceAll('_', ' ').contains(deviceName);
      } else {
        // running simulator
        return device.name.contains(deviceName);
      }
    } else {
      if (device.platformType == 'ios') {
        // real ios device
        return device.iosModel.contains(deviceName);
      } else {
        // real android device
        return device.name.contains(deviceName);
      }
    }
  }, orElse: () => null);
}

/// Set the simulator locale.
/// (Startup managed elsewhere)
/// Returns true of locale changed.
Future<bool> setSimulatorLocale(String deviceId, String deviceName,
    String testLocale, String stagingDir, DaemonClient daemonClient) async {
  // a running simulator
  final deviceLocale = utils.getIosSimulatorLocale(deviceId);
  printTrace('\'$deviceName\' locale: $deviceLocale, test locale: $testLocale');
  bool localeChanged = false;
  if (Intl.canonicalizedLocale(testLocale) !=
      Intl.canonicalizedLocale(deviceLocale)) {
    printStatus(
        'Changing locale from $deviceLocale to $testLocale on \'$deviceName\'...');
    await _changeSimulatorLocale(stagingDir, deviceId, testLocale);
    localeChanged = true;
  }
  return localeChanged;
}

/// Set the locale of a running emulator.
Future<void> setEmulatorLocale(String deviceId, testLocale, deviceName) async {
  final deviceLocale = utils.getAndroidDeviceLocale(deviceId);
  printTrace('\'$deviceName\' locale: $deviceLocale, test locale: $testLocale');
  if (deviceLocale != null &&
      deviceLocale != '' &&
      Intl.canonicalizedLocale(deviceLocale) !=
          Intl.canonicalizedLocale(testLocale)) {
    //          daemonClient.verbose = true;
    printStatus(
        'Changing locale from $deviceLocale to $testLocale on \'$deviceName\'...');
    changeAndroidLocale(deviceId, deviceLocale, testLocale);
    //          daemonClient.verbose = false;
    await utils.waitAndroidLocaleChange(deviceId, testLocale);
    // allow additional time before orientation change
//    await Future.delayed(Duration(milliseconds: 5000));
    await Future.delayed(Duration(milliseconds: 1000));
  }
}

/// Change local of real android device or running emulator.
void changeAndroidLocale(
    String deviceId, String deviceLocale, String testLocale) {
  if (cmd([getAdbPath(androidSdk), '-s', deviceId, 'root']) ==
      'adbd cannot run as root in production builds\n') {
    stdout.write(
        'Warning: locale will not be changed. Running in locale \'$deviceLocale\'.\n');
    stdout.write(
        'To change locale you must use a non-production emulator (one that does not depend on Play Store). See:\n');
    stdout.write(
        '    https://stackoverflow.com/questions/43923996/adb-root-is-not-working-on-emulator/45668555#45668555 for details.\n');
  }
  // adb shell "setprop persist.sys.locale fr_CA; setprop ctl.restart zygote"
  cmd([
    getAdbPath(androidSdk),
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
  await streamCmd([
    '$stagingDir/resources/script/simulator-controller',
    name,
    'locale',
    testLocale
  ]);
}

/// Shutdown an android emulator.
Future<String> shutdownAndroidEmulator(
    DaemonClient daemonClient, String deviceId) async {
  cmd([getAdbPath(androidSdk), '-s', deviceId, 'emu', 'kill']);
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
  final androidHome = platform.environment['ANDROID_HOME'];
  await streamCmd([
    '$androidHome/emulator/emulator',
    '-avd',
    emulatorId,
    '-no-audio',
    '-no-window',
    '-no-snapshot',
    '-gpu',
    'swiftshader',
  ], mode: ProcessStartMode.detached);
  // wait for emulator to start
  await streamCmd(['$stagingDir/resources/script/android-wait-for-emulator']);
}

/// Get device type from config info
DeviceType getDeviceType(Config config, String deviceName) {
  return config.getDevice(deviceName).deviceType;
}

/// Check Image Magick is installed.
Future<bool> isImageMagicInstalled() async {
  return await runInContext<bool>(() {
    final cmd =
        platform.isWindows ? ['magick', '-version'] : ['convert', '-version'];
    return runCmd(cmd) == 0;
  });
}
