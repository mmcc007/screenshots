import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path/path.dart';

/// Clear directory [dirPath].
/// Create directory if none exists.
void clearDirectory(String dirPath) {
  if (Directory(dirPath).existsSync()) {
    Directory(dirPath).deleteSync(recursive: true);
  } else {
    Directory(dirPath).createSync(recursive: true);
  }
}

/// Clear files in a directory [dirPath] ending in [suffix]
/// Create directory if none exists.
void clearFilesWithSuffix(String dirPath, String suffix) {
  // delete files with suffix
  if (Directory(dirPath).existsSync()) {
    Directory(dirPath).listSync().toList().forEach((e) {
      if (extension(e.path) == suffix) {
        File(e.path).delete();
      }
    });
  } else {
    Directory(dirPath).createSync(recursive: true);
  }
}

/// Move files from [srcDir] to [dstDir].
///
/// If dstDir does not exist, it is created.
void moveFiles(String srcDir, String dstDir) {
  if (!Directory(dstDir).existsSync()) {
    Directory(dstDir).createSync(recursive: true);
  }
  Directory(srcDir).listSync().forEach((file) {
    file.renameSync('$dstDir/${p.basename(file.path)}');
  });
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
    throw 'command failed: cmd=\'$cmd ${arguments.join(" ")}\'';
  }
  // return stdout
  return result.stdout;
}

/// Execute command [cmd] with arguments [arguments] in a separate process
/// and stream stdout/stderr.
Future<void> streamCmd(String cmd, List<String> arguments,
    [String workingDirectory = '.',
    ProcessStartMode mode = ProcessStartMode.normal]) async {
//  print(
//      'streamCmd=\'$cmd ${arguments.join(" ")}\', workingDirectory=$workingDirectory, mode=$mode');

  final process = await Process.start(cmd, arguments,
      workingDirectory: workingDirectory, mode: mode);

  final stdoutFuture = process.stdout
      .transform(utf8.decoder)
      .transform(LineSplitter())
      .listen(stdout.writeln)
      .asFuture();
  final stderrFuture = process.stderr
      .transform(utf8.decoder)
      .transform(LineSplitter())
      .listen(stderr.writeln)
      .asFuture();

  await Future.wait([stdoutFuture, stderrFuture]);

  var exitCode = await process.exitCode;
  if (exitCode != 0) {
    throw 'command failed: cmd=\'$cmd ${arguments.join(" ")}\'';
  }
}

/// Creates a list of available iOS simulators.
/// (really just concerned with simulators for now).
/// Provides access to their IDs and status'.
Map getIosSimulators() {
  final simulators =
      cmd('xcrun', ['simctl', 'list', 'devices', '--json'], '.', true);
  final simulatorsInfo = jsonDecode(simulators)['devices'];
  return transformIosSimulators(simulatorsInfo);
}

/// Transforms latest information about iOS simulators into more convenient
/// format to index into by simulator name.
/// (also useful for testing)
Map transformIosSimulators(Map simsInfo) {
  // transform json to a Map of device name by a map of iOS versions by a list of
  // devices with a map of properties
  // ie, Map<String, Map<String, List<Map<String, String>>>>
  // In other words, just pop-out the device name for 'easier' access to
  // the device properties.
  Map simsInfoTransformed = {};

  simsInfo.forEach((iOSName, sims) {
    //    print('iOSVersionName=$iOSVersionName');
    // note: 'isAvailable' field does not appear consistently
    //       so using 'availability' instead
    isSimAvailable(sim) => sim['availability'] == '(available)';
    for (final sim in sims) {
      // skip if simulator unavailable
      if (!isSimAvailable(sim)) continue;

      // init iOS versions map if not already present
      if (simsInfoTransformed[sim['name']] == null) {
        simsInfoTransformed[sim['name']] = {};
      }

      // init iOS version simulator array if not already present
      // note: there can be multiple versions of a simulator with the same name
      //       for an iOS version, hence the use of an array.
      if (simsInfoTransformed[sim['name']][iOSName] == null) {
        simsInfoTransformed[sim['name']][iOSName] = [];
      }

      // add simulator to iOS version simulator array
      simsInfoTransformed[sim['name']][iOSName].add(sim);
    }
  });
  return simsInfoTransformed;
}

// finds the iOS simulator with the highest available iOS version
Map getHighestIosSimulator(Map iosSims, String simName) {
  final Map iOSVersions = iosSims[simName];

  // get highest iOS version
  var iOSVersionName = getHighestIosVersion(iOSVersions);

  final iosVersionSims = iosSims[simName][iOSVersionName];
  if (iosVersionSims.length == 0) {
    throw "Error: no simulators found for \'$simName\'";
  }
  // use the first device found for the iOS version
  return iosVersionSims[0];
}

// returns name of highest iOS version names
String getHighestIosVersion(Map iOSVersions) {
  // sort keys in iOS version order
  final iosVersionNames = iOSVersions.keys.toList();
//  print('keys=$iosVersionKeys');
  iosVersionNames.sort((v1, v2) {
    return v1.compareTo(v2);
  });
//  print('keys (sorted)=$iosVersionKeys');

  // get the highest iOS version
  final iOSVersionName = iosVersionNames.last;
  return iOSVersionName;
}

/// Create list of avds,
List<String> getAvdNames() {
  return cmd('emulator', ['-list-avds'], '.', true).split('\n');
}

/// Get the highest available avd version for the android emulator.
String getHighestAVD(String deviceName) {
  final emulatorName = deviceName.replaceAll(' ', '_');
  final avds =
      getAvdNames().where((name) => name.contains(emulatorName)).toList();
  // sort list in android API order
  avds.sort((v1, v2) {
    return v1.compareTo(v2);
  });

  return avds.last;
}

/// Adds prefix to all files in a directory
Future prefixFilesInDir(String dirPath, String prefix) async {
  await for (final file
      in Directory(dirPath).list(recursive: false, followLinks: false)) {
    await file
        .rename(p.dirname(file.path) + '/' + prefix + p.basename(file.path));
  }
}

/// Converts [enum] value to [String].
String enumToStr(dynamic _enum) => _enum.toString().split('.').last;

/// Returns locale of currently attached android device.
String androidDeviceLocale(String deviceId) {
  final deviceLocale = cmd('adb',
          ['-s', deviceId, 'shell', 'getprop persist.sys.locale'], '.', true)
      .trim();
  return deviceLocale;
}

/// Returns locale of simulator with udid [udId].
String iosSimulatorLocale(String udId) {
  final env = Platform.environment;
  final settingsPath =
      '${env['HOME']}/Library/Developer/CoreSimulator/Devices/$udId/data/Library/Preferences/.GlobalPreferences.plist';
  final localeInfo = jsonDecode(
      cmd('plutil', ['-convert', 'json', '-o', '-', settingsPath], '.', true));
  final locale = localeInfo['AppleLocale'];
  return locale;
}

/// Get android emulator id from a running emulator with id [deviceId].
/// Returns emulator id as [String].
String getAndroidEmulatorId(String deviceId) {
  return cmd('adb', ['-s', deviceId, 'emu', 'avd', 'name'], '.', true)
      .split('\r\n')
      .map((line) => line.trim())
      .first;
}

/// Find android device id with matching [emulatorId].
/// Returns matching android device id as [String].
String findAndroidDeviceId(String emulatorId) {
  final devicesIds = getAndroidDeviceIds();
  if (devicesIds.length == 0) return null;
  return devicesIds.firstWhere(
      (deviceId) => emulatorId == getAndroidEmulatorId(deviceId),
      orElse: () => null);
}

/// Get the list of running devices by id.
List<String> getAndroidDeviceIds() {
  return cmd('adb', ['devices'], '.', true)
      .trim()
      .split('\n')
      .sublist(1) // remove first line
      .map((device) => device.split('\t').first)
      .toList();
}

/// Get deviceId for a booting emulator
Future<String> getBootedAndroidDeviceId(String deviceName) async {
  final avdName = getHighestAVD(deviceName);
  final pollingInterval = 500;
  String deviceId = null;
  final poller = Poller(() async {
    deviceId = findAndroidDeviceId(avdName);
  }, Duration(milliseconds: pollingInterval),
      initialDelay: Duration(milliseconds: pollingInterval));
  while (deviceId == null) {
    print('Waiting for $deviceName to boot...');
    await Future.delayed(Duration(milliseconds: pollingInterval));
  }
  poller.cancel();
  return deviceId;
}

Future stopEmulator(String deviceId, String stagingDir) async {
  cmd('adb', ['-s', deviceId, 'emu', 'kill']);
  // wait for emulator to stop
  await streamCmd(
      '$stagingDir/resources/script/android-wait-for-emulator-to-stop',
      [deviceId]);
}

/// Wait for android emulator to stop.
Future<void> waitAndroidEmulatorShutdown(
    String deviceId, String deviceName) async {
  final pollingInterval = 500;
  final notFound = 'not found';
  String status = '';
  final poller = Poller(() async {
    status = cmd(
            'sh',
            [
              '-c',
              'adb -s $deviceId -e shell getprop sys.boot_completed || echo \"$notFound\"'
            ],
            '.',
            true)
        .trim();
  }, Duration(milliseconds: pollingInterval));

  while (!(status == notFound)) {
    print('Waiting for \'$deviceName\' to shutdown...');
    await Future.delayed(Duration(milliseconds: pollingInterval));
//    print('status=$status');
  }
  poller.cancel();
  print('... \'$deviceName\' shutdown complete.');
}

// from https://github.com/flutter/flutter/blob/master/packages/flutter_tools/lib/src/base/utils.dart#L255-L292
typedef AsyncCallback = Future<void> Function();

/// A [Timer] inspired class that:
///   - has a different initial value for the first callback delay
///   - waits for a callback to be complete before it starts the next timer
class Poller {
  Poller(this.callback, this.pollingInterval,
      {this.initialDelay = Duration.zero}) {
    Future<void>.delayed(initialDelay, _handleCallback);
  }

  final AsyncCallback callback;
  final Duration initialDelay;
  final Duration pollingInterval;

  bool _canceled = false;
  Timer _timer;

  Future<void> _handleCallback() async {
    if (_canceled) return;

    try {
      await callback();
    } catch (error) {
      print('Error from poller: $error');
    }

    if (!_canceled) _timer = Timer(pollingInterval, _handleCallback);
  }

  /// Cancels the poller.
  void cancel() {
    _canceled = true;
    _timer?.cancel();
    _timer = null;
  }
}

/// Filters a list of devices to get real ios devices
List getIosDevices(List devices) {
  final iosDevices = devices
      .where((device) => device['platform'] == 'ios' && !device['emulator'])
      .toList();
  return iosDevices;
}

/// Filters a list of devices to get real android devices
List getAndroidDevices(List devices) {
  final iosDevices = devices
      .where((device) => device['platform'] != 'ios' && !device['emulator'])
      .toList();
  return iosDevices;
}

/// Get all android and ios devices
List getAllDevices(Map configInfo) {
  final androidDeviceNames = configInfo['devices']['android']?.keys ?? [];
  final iosDeviceNames = configInfo['devices']['ios']?.keys ?? [];
  final deviceNames = [...androidDeviceNames, ...iosDeviceNames];
  return deviceNames;
}
