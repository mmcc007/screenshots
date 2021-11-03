import 'dart:async';

import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:tool_base/tool_base.dart' hide Config;
import 'package:tool_mobile/tool_mobile.dart';

import 'archive.dart';
import 'config.dart';
import 'context_runner.dart';
import 'daemon_client.dart';
import 'fastlane.dart' as fastlane;
import 'globals.dart';
import 'image_processor.dart';
import 'orientation.dart';
import 'resources.dart' as resources;
import 'screens.dart';
import 'utils.dart' as utils;
import 'validate.dart' as validate;

/// Run screenshots
Future<bool> screenshots(
    {required String configPath,
    String? configStr,
    required RunMode runMode,
    String? flavor,
    bool? isBuild,
    bool isVerbose = false}) async {
  final screenshots = Screenshots(
      config: Config(configPath: configPath, configStr: configStr),
      runMode: runMode,
      flavor: flavor,
      isBuild: isBuild,
      verbose: isVerbose);
  // run in context
  if (isVerbose) {
    Logger verboseLogger = VerboseLogger(
        platform.isWindows ? WindowsStdoutLogger() : StdoutLogger());
    return runInContext<bool>(() async {
      return screenshots.run();
    }, overrides: <Type, Generator>{
      Logger: () => verboseLogger,
    });
  } else {
    return runInContext<bool>(() async {
      return screenshots.run();
    });
  }
}

class Screenshots {
  Screenshots({
    required this.config,
    this.runMode = RunMode.normal,
    this.flavor,
    this.isBuild,
    this.verbose = false,
  });

  final String? flavor;
  final bool? isBuild;
  final bool verbose;

  final RunMode runMode;
  final Screens screens = Screens();
  final Config config;
  List<DaemonDevice> devices = [];
  List<DaemonEmulator> emulators=[];
  Archive? archive;

  /// Capture screenshots, process, and load into fastlane according to config file.
  ///
  /// For each locale and device or emulator/simulator:
  ///
  /// 1. If not a real device, start the emulator/simulator for current locale.
  /// 2. Run each integration test and capture the screenshots.
  /// 3. Process the screenshots including adding a frame if required.
  /// 4. Move processed screenshots to fastlane destination for upload to stores.
  /// 5. If not a real device, stop emulator/simulator.
  Future<bool> run() async {
    // start flutter daemon
    final status = logger.startProgress('Starting flutter daemon...',
        timeout: Duration(milliseconds: 10000));
    await daemonClient.start;
    status.stop();

    // get all attached devices and running emulators/simulators
    devices = await daemonClient.devices;
    // get all available unstarted android emulators
    // note: unstarted simulators are not properly included in this list
    //       so have to be handled separately
    emulators = await daemonClient.emulators;
    emulators.sort(utils.emulatorComparison);

    // validate config file
    if (!await validate.isValidConfig(config, screens, devices, emulators)) {
      return false;
    }

    // init
    await fs
        .directory(path.join(config.stagingDir, kTestScreenshotsDir))
        .create(recursive: true);
    if (!platform.isWindows) await resources.unpackScripts(config.stagingDir);
    if (runMode == RunMode.archive) {
      archive = Archive(config.archiveDir!);
      printStatus('Archiving screenshots to ${archive?.archiveDirPrefix}...');
    } else {
      await fastlane.clearFastlaneDirs(config, screens, runMode);
    }

    // run integration tests in each real device (or emulator/simulator) for
    // each locale and process screenshots
    await runTestsOnAll();

    // shutdown daemon
    await daemonClient.stop;

    printStatus('\n\nScreen images are available in:');
    if (runMode == RunMode.recording) {
      _printScreenshotDirs(config.recordingDir);
    } else {
      if (runMode == RunMode.archive) {
        printStatus('  ${archive?.archiveDirPrefix}');
      } else {
        _printScreenshotDirs(null);
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

  void _printScreenshotDirs(String? dirPrefix) {
    final prefix = dirPrefix == null ? '' : '$dirPrefix/';
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
  Future runTestsOnAll() async {
    switch (runMode) {
      case RunMode.normal:
        break;
      case RunMode.recording:
        config.recordingDir == null
            ? throw 'Error: \'recording\' dir is not specified in your screenshots.yaml'
            : null;
        break;
      case RunMode.comparison:
        runMode == RunMode.comparison &&
                (!(await utils.isRecorded(config.recordingDir!)))
            ? throw 'Error: a recording must be run before a comparison'
            : null;
        break;
      case RunMode.archive:
        config.archiveDir == null
            ? throw 'Error: \'archive\' dir is not specified in your screenshots.yaml'
            : null;
        break;
    }

    for (final d in config.devices) {
      // look for matching device first.
      // Note: flutter daemon handles devices and running emulators/simulators as devices.
      final device = findRunningDevice(devices, emulators, d.name);

      String deviceId;
      DaemonEmulator? emulator;
      Map? simulator;
      var pendingIosLocaleChangeAtStart = false;
      if (device != null) {
        deviceId = device.id;
      } else {
        // if no matching device, look for matching android emulator
        // and start it
        emulator = utils.findEmulator(emulators, d.name);
        if (emulator != null) {
          printStatus('Starting ${d.name}...');
          deviceId = await startEmulator(daemonClient, emulator.id, config.stagingDir);
        } else {
          // if no matching android emulator, look for matching ios simulator
          // and start it
          simulator = utils.getHighestIosSimulator(
              utils.getIosSimulators(), d.name);
          deviceId = simulator['udid'];
          // check if current simulator is pending a locale change
          if (Intl.canonicalizedLocale(config.locales[0]) ==
              Intl.canonicalizedLocale(utils.getIosSimulatorLocale(deviceId))) {
            printStatus('Starting ${d.name}...');
            await startSimulator(daemonClient, deviceId);
          } else {
            pendingIosLocaleChangeAtStart = true;
            printTrace(
                'Postponing \'${d.name}\' startup due to pending locale change');
          }
        }
      }

      // a device is now found
      // (and running if not ios simulator pending locale change)

      // todo: make a backup of GlobalPreferences.plist if changing iOS locale
      // set locale and run tests
      if (device != null && !device.emulator) {
        // device is real
        final defaultLocale =
            'en_US'; // todo: need actual locale of real device
        printStatus('Warning: the locale of a real device cannot be changed.');
        printStatus('Warning: currently defaulting to locale $defaultLocale.');
        await runProcessTests(
          d,
          defaultLocale,
          null,
          deviceId,
        );
      } else {
        // device is emulated

        // Function to check for a running android device or emulator.
        bool isRunningAndroidDeviceOrEmulator(
            DaemonDevice? device, DaemonEmulator? emulator) {
          return (device != null && device.deviceType != DeviceType.ios) ||
              (device == null && emulator != null);
        }

        // save original android locale for reverting later if necessary
        String? origAndroidLocale;
        if (isRunningAndroidDeviceOrEmulator(device, emulator!)) {
          origAndroidLocale = utils.getAndroidDeviceLocale(deviceId);
        }

        // Function to check for a running ios device or simulator.
        bool isRunningIosDeviceOrSimulator(DaemonDevice? device) {
          return (device != null && device.deviceType == DeviceType.ios) ||
              (device == null && simulator != null);
        }

        // save original ios locale for reverting later if necessary
        String? origIosLocale;
        if (isRunningIosDeviceOrSimulator(device)) {
          origIosLocale = utils.getIosSimulatorLocale(deviceId);
        }

        for (final locale in config.locales) {
          // set locale if android device or emulator
          if (isRunningAndroidDeviceOrEmulator(device, emulator)) {
            await setEmulatorLocale(deviceId, locale, d.name);
          }
          // set locale if ios simulator
          if ((device != null && device.deviceType == DeviceType.ios && device.emulator) ||
              (device == null &&
                  simulator != null &&
                  !pendingIosLocaleChangeAtStart)) {
            // an already running simulator or a started simulator
            final localeChanged = await setSimulatorLocale(deviceId,
                d.name, locale, config.stagingDir, daemonClient);
            if (localeChanged) {
              // restart simulator
              printStatus(
                  'Restarting \'${d.name}\' due to locale change...');
              await shutdownSimulator(deviceId);
              await startSimulator(daemonClient, deviceId);
            }
          }
          if (pendingIosLocaleChangeAtStart) {
            // a non-running simulator
            await setSimulatorLocale(deviceId, d.name, locale,
                config.stagingDir, daemonClient);
            printStatus('Starting ${d.name}...');
            await startSimulator(daemonClient, deviceId);
            pendingIosLocaleChangeAtStart = false;
          }

          // Change orientation if required
          if (d.orientations.isNotEmpty) {
            for (final orientation in d.orientations) {
              final currentDevice =
                  utils.getDeviceFromId(await daemonClient.devices, deviceId);
              currentDevice == null
                  ? throw 'Error: device \'${d.name}\' not found in flutter daemon.'
                  : null;
              switch (d.deviceType) {
                case DeviceType.android:
                  if (currentDevice.emulator) {
                    changeDeviceOrientation(d.deviceType, orientation,
                        deviceId: deviceId);
                  } else {
                    printStatus(
                        'Warning: cannot change orientation of a real android device.');
                  }
                  break;
                case DeviceType.ios:
                  if (currentDevice.emulator) {
                    changeDeviceOrientation(d.deviceType, orientation,
                        scriptDir: '${config.stagingDir}/resources/script');
                  } else {
                    printStatus(
                        'Warning: cannot change orientation of a real iOS device.');
                  }
                  break;
              }

              // store env for later use by tests
              // ignore: invalid_use_of_visible_for_testing_member
              await config.storeEnv(ScreenshotsEnv(
                screen: screens.getScreen(d.name)!,
                device: d,
                locale: locale,
                orientation: orientation,
              ));

              // run tests and process images
              await runProcessTests(
                d,
                locale,
                orientation,
                deviceId,
              );
            }
          } else {
            await runProcessTests(
              d,
              locale,
              null,
              deviceId,
            );
          }
        }
        // if an emulator was started, revert locale if necessary and shut it down
        if (origAndroidLocale != null) {
          await setEmulatorLocale(
              deviceId, origAndroidLocale, d.name);
          await shutdownAndroidEmulator(daemonClient, deviceId);
        }
        // if a simulator was started, revert locale if necessary and shut it down
        if (simulator != null && origIosLocale != null) {
          // todo restore backup of GlobalPreferences.plist
          await setSimulatorLocale(deviceId, d.name, origIosLocale,
              config.stagingDir, daemonClient);
          await shutdownSimulator(deviceId);
        }
      }
    }
  }

  /// Runs tests and processes images.
  Future runProcessTests(
    ConfigDevice device,
    String locale,
    Orientation? orientation,
    String deviceId,
  ) async {
    for (final testPath in config.tests) {
      final command = ['flutter', '-d', deviceId, 'drive'];
      bool _isBuild() => isBuild ?? device.isBuild;
      if (!_isBuild()) {
        command.add('--no-build');
      }
      bool isFlavor() => flavor != null;
      if (flavor != null) {
        command.addAll(['--flavor', flavor!]);
      }
      command.addAll(testPath.split(" ")); // add test path or custom command
      printStatus('Running: ${command.join(" ")}');
      if (!_isBuild() && isFlavor()) {
        printStatus(
            'Warning: flavor parameter \'$flavor\' is ignored because no build is set for this device');
      }
      // final cp = configPath;
      await utils.streamCmd(command,
          environment: /*cp != null ? {kEnvConfigPath: cp} : */{});
      // process screenshots
      final imageProcessor = ImageProcessor(config);
      await imageProcessor.process(
          device, locale, orientation, runMode, archive);
    }
  }
}

Future<void> shutdownSimulator(String deviceId) async {
  utils.cmd(['xcrun', 'simctl', 'shutdown', deviceId]);
  // shutdown apparently needs time when restarting
  // see https://github.com/flutter/flutter/issues/10228 for race condition on simulator
  await Future.delayed(Duration(milliseconds: 2000));
}

Future<void> startSimulator(DaemonClient daemonClient, String deviceId) async {
  utils.cmd(['xcrun', 'simctl', 'boot', deviceId]);
  await Future.delayed(Duration(milliseconds: 2000));
  await waitForEmulatorToStart(daemonClient, deviceId);
}

/// Start android emulator and return device id.
Future<String> startEmulator(
    DaemonClient daemonClient, String emulatorId, stagingDir) async {
//  if (utils.isCI()) {
//    // testing on CI/CD requires starting emulator in a specific way
//    await _startAndroidEmulatorOnCI(emulatorId, stagingDir);
//    return utils.findAndroidDeviceId(emulatorId);
//  } else {
    // testing locally, so start emulator in normal way
    return await daemonClient.launchEmulator(emulatorId);
//  }
}

/// Find a real device or running emulator/simulator for [deviceName].
/// Note: flutter daemon handles devices and running emulators/simulators as devices.
DaemonDevice? findRunningDevice(List<DaemonDevice> devices,
    List<DaemonEmulator> emulators, String deviceName) {
  return devices.where((DaemonDevice device) {
//    // hack for CI testing. Platform is reporting as 'android-arm' instead of 'android-x86'
//    if (device.platform == 'android-arm') {
//      /// Find the device name of a running emulator.
//      String findDeviceNameOfRunningEmulator(
//          List<DaemonEmulator> emulators, String deviceId) {
//        final emulatorId = utils.getAndroidEmulatorId(deviceId);
//        final emulator = emulators.firstWhere(
//            (emulator) => emulator.id == emulatorId,
//            orElse: () => null);
//        return emulator == null ? null : emulator.name;
//      }
//
//      final emulatorName =
//          findDeviceNameOfRunningEmulator(emulators, device.id);
//      return emulatorName.contains(deviceName);
//    }

    if (device.emulator) {
      if (device.deviceType == DeviceType.android) {
        // running emulator
        return device.emulatorId.replaceAll('_', ' ').toUpperCase().contains(
            deviceName.toUpperCase());
      } else {
        // running simulator
        return device.name.contains(deviceName);
      }
    } else {
      if (device.deviceType == DeviceType.ios) {
        // real ios device
        return device.iosModel?.contains(deviceName) ?? false;
      } else {
        // real android device
        return device.name.contains(deviceName);
      }
    }
  })
      .toList()
      .firstOrNull;
}

/// Set the simulator locale.
/// (Startup managed elsewhere)
/// Returns true of locale changed.
Future<bool> setSimulatorLocale(String deviceId, String deviceName,
    String testLocale, String stagingDir, DaemonClient daemonClient) async {
  // a running simulator
  final deviceLocale = utils.getIosSimulatorLocale(deviceId);
  printTrace('\'$deviceName\' locale: $deviceLocale, test locale: $testLocale');
  var localeChanged = false;
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
Future<void> setEmulatorLocale(String deviceId, String testLocale, String deviceName) async {
  final deviceLocale = utils.getAndroidDeviceLocale(deviceId);
  printTrace("$deviceName locale: $deviceLocale, test locale: $testLocale");
  if (deviceLocale != null &&
      deviceLocale != '' &&
      Intl.canonicalizedLocale(deviceLocale) !=
          Intl.canonicalizedLocale(testLocale)) {
    //          daemonClient.verbose = true;
    if (changeAndroidLocale(deviceId, deviceLocale, testLocale)) {
      //          daemonClient.verbose = false;
      await utils.waitAndroidLocaleChange(deviceId, testLocale);
      // allow additional time before orientation change
//    await Future.delayed(Duration(milliseconds: 5000));
      await Future.delayed(Duration(milliseconds: 1000));
    }
  }
}

/// Change local of real android device or running emulator.
bool changeAndroidLocale(String deviceId, String deviceLocale,
    String testLocale) {
  if (utils.cmd([getAdbPath(androidSdk), '-s', deviceId, 'root']) ==
      'adbd cannot run as root in production builds\n') {
    printError(
        'Warning: locale will not be changed. Running in locale \'$deviceLocale\'.\n');
    printError(
        'To change locale you must use a non-production emulator (one that does not depend on Play Store). See:\n');
    printError(
        '    https://stackoverflow.com/questions/43923996/adb-root-is-not-working-on-emulator/45668555#45668555 for details.\n');
    return false;
  }
  printStatus(
      "Changing locale from $deviceLocale to $testLocale on '$deviceId'...");

  // adb shell "setprop persist.sys.locale fr_CA; setprop ctl.restart zygote"
  utils.cmd([
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

  return true;
}

/// Change locale of non-running simulator.
Future<void> _changeSimulatorLocale(String stagingDir, String name,
    String testLocale) async =>
    await utils.streamCmd([
      '$stagingDir/resources/script/simulator-controller',
      name,
      'locale',
      testLocale
    ]);

/// Shutdown an android emulator.
Future<String> shutdownAndroidEmulator(
    DaemonClient daemonClient, String deviceId) async {
  utils.cmd([getAdbPath(androidSdk), '-s', deviceId, 'emu', 'kill']);
//  await waitAndroidEmulatorShutdown(deviceId);
  final device = await daemonClient.waitForEvent(EventType.deviceRemoved);
  if (device['id'] != deviceId) {
    throw 'Error: device id \'$deviceId\' not shutdown';
  }
  return device['id'];
}

///// Start android emulator in a CI environment.
//Future _startAndroidEmulatorOnCI(String emulatorId, String stagingDir) async {
//  // testing on CI/CD requires starting emulator in a specific way
//  final androidHome = platform.environment['ANDROID_HOME'];
//  await utils.streamCmd([
//    '$androidHome/emulator/emulator',
//    '-avd',
//    emulatorId,
//    '-no-audio',
//    '-no-window',
//    '-no-snapshot',
//    '-gpu',
//    'swiftshader',
//  ], mode: ProcessStartMode.detached);
//  // wait for emulator to start
//  await utils
//      .streamCmd(['$stagingDir/resources/script/android-wait-for-emulator']);
//}

/// Get device type from config info
DeviceType? getDeviceType(Config config, String deviceName) {
  return config.getDevice(deviceName)?.deviceType;
}

