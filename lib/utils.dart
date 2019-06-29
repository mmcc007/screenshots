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
    [String workingDir = '.', bool silent = false, bool keepNewline = true]) {
//  print(
//      'cmd=\'$cmd ${arguments.join(" ")}\', workingDir=$workingDir, silent=$silent, keepNewLine=$keepNewline');
  final result = Process.runSync(cmd, arguments, workingDirectory: workingDir);
  if (!silent) stdout.write(result.stdout);
  if (result.exitCode != 0) {
    stderr.write(result.stderr);
    throw 'command failed: cmd=\'$cmd ${arguments.join(" ")}\'';
  }
//  print('stdout=${result.stdout}');
  if (keepNewline) {
    // return stdout
    return result.stdout;
  } else {
    // remove last char if newline
    return removeNewline(result.stdout);
  }
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

  if (mode == ProcessStartMode.normal) {
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
}

/// Creates a list of available iOS devices.
/// (really just concerned with simulators for now).
/// Provides access to their IDs and status'.
Map getIosDevices() {
  final deviceInfoRaw =
      cmd('xcrun', ['simctl', 'list', 'devices', '--json'], '.', true);
  final deviceInfo = jsonDecode(deviceInfoRaw)['devices'];
  return transformIosDevices(deviceInfo);
}

/// Transforms latest information about iOS devices into more convenient
/// format to index into by device name.
/// (also useful for testing)
Map transformIosDevices(deviceInfo) {
  // transform json to a Map of device name by a map of iOS versions by a list of
  // devices with a map of properties
  // ie, Map<String, Map<String, List<Map<String, String>>>>
  // In other words, just pop-out the device name for 'easier' access to
  // the device properties.
  Map deviceInfoTransformed = {};

  deviceInfo.forEach((iOSName, devices) {
    //    print('iOSVersionName=$iOSVersionName');
    // note: 'isAvailable' field does not appear consistently
    //       so using 'availability' instead
    isDeviceAvailable(device) => device['availability'] == '(available)';
    for (var device in devices) {
      // skip unavailable devices
      if (!isDeviceAvailable(device)) continue;

      //      print('device=$device');
      // init iOS versions map if not already present
      if (deviceInfoTransformed[device['name']] == null) {
        deviceInfoTransformed[device['name']] = {};
      }

      // init iOS version device array if not already present
      // note: there can be multiple versions of a device with the same name
      //       for an iOS version, hence the use of an array.
      if (deviceInfoTransformed[device['name']][iOSName] == null) {
        deviceInfoTransformed[device['name']][iOSName] = [];
      }

      // add device to iOS version device array
      deviceInfoTransformed[device['name']][iOSName].add(device);
    }
  });
  return deviceInfoTransformed;
}

// finds the iOS device with the highest available iOS version
Map getHighestIosDevice(Map iosDevices, String deviceName) {
  final Map iOSVersions = iosDevices[deviceName];

  // get highest iOS version
  var iOSVersionName = getHighestIosVersion(iOSVersions);

  final iosVersionDevices = iosDevices[deviceName][iOSVersionName];
  if (iosVersionDevices.length == 0) {
    throw "Error: no available devices found for \'$deviceName\'";
  }
  // use the first device found for the iOS version
  return iosVersionDevices[0];
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

/// Create list of emulators
List<String> emulators() {
  return cmd('emulator', ['-list-avds'], '.', true).split('\n');
}

/// Find the android device with the highest available android version
String getHighestAndroidDevice(String deviceName) {
  final deviceNameNormalized = deviceName.replaceAll(' ', '_');
  final devices =
      emulators().where((name) => name.contains(deviceNameNormalized)).toList();
  // sort list in android API order
  devices.sort((v1, v2) {
    return v1.compareTo(v2);
  });

  return devices.last;
}

/// Adds prefix to all files in a directory
Future prefixFilesInDir(String dirPath, String prefix) async {
  await for (final file
      in Directory(dirPath).list(recursive: false, followLinks: false)) {
    await file
        .rename(p.dirname(file.path) + '/' + prefix + p.basename(file.path));
  }
}

/// Check if any device is running.
bool isAnyDeviceRunning() {
  return !cmd('flutter', ['devices'], '.', true)
      .contains('No devices detected.');
}

/// Converts [enum] value to [String].
String enumToStr(dynamic _enum) => _enum.toString().split('.').last;

/// Remove newline at end of [str] if present.
String removeNewline(String str) {
  String cleanStr = '';
  str.endsWith('\n')
      ? cleanStr = str.substring(0, str.length - 1)
      : cleanStr = str;
  return cleanStr;
}

/// Returns locale of currently attached android device.
String androidDeviceLocale(String deviceId) {
  final deviceLocale = cmd(
      'adb',
      ['-s', deviceId, 'shell', 'getprop persist.sys.locale'],
      '.',
      true,
      false);
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

/// Get AVD name from device id [deviceId].
/// Returns AVD name as [String].
String getAvdName(String deviceId) {
  return cmd('adb', ['-s', deviceId, 'emu', 'avd', 'name'], '.', true)
      .split('\r\n')
      .map((line) => line.trim())
      .first;
}

/// Find android device id with matching [avdName].
/// Returns matching android device id as [String].
String findAndroidDeviceId(String avdName) {
  final devicesIds = getAndroidDevices();
  if (devicesIds.length == 0) return null;
  return devicesIds.firstWhere((id) => avdName == getAvdName(id), orElse: null);
}

/// Get the list of running devices
List<String> getAndroidDevices() {
  return cmd('adb', ['devices'], '.', true)
      .trim()
      .split('\n')
      .sublist(1)
      .map((device) => device.split('\t').first)
      .toList();
}
