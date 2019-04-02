import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Clear directory [dir].
/// Create directory if none exists.
void clearDirectory(String dir) {
  if (Directory(dir).existsSync()) {
    Directory(dir).deleteSync(recursive: true);
  }
  Directory(dir).createSync(recursive: true);
}

/// Move files from [srcDir] to [dstDir].
///
/// If dstDir does not exist, it is created.
void moveFiles(String srcDir, String dstDir) {
  if (!Directory(dstDir).existsSync())
    Directory(dstDir).createSync(recursive: true);
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
//  print('cmd=\'$cmd ${arguments.join(" ")}\'');
  final result = Process.runSync(cmd, arguments, workingDirectory: workingDir);
  if (!silent) stdout.write(result.stdout);
  if (result.exitCode != 0) {
    stderr.write(result.stderr);
    throw 'command failed: cmd=\'$cmd ${arguments.join(" ")}\'';
  }
  return result.stdout;
}

/// Execute command [cmd] with arguments [arguments] in a separate process
/// and stream stdout/stderr.
Future<void> streamCmd(String cmd, List<String> arguments,
    [ProcessStartMode mode = ProcessStartMode.normal]) async {
//  print('streamCmd=\'$cmd ${arguments.join(" ")}\'');

  final process = await Process.start(cmd, arguments, mode: mode);

  if (mode == ProcessStartMode.normal) {
    var stdOutLineStream =
        process.stdout.transform(Utf8Decoder()).transform(LineSplitter());
    await for (var line in stdOutLineStream) {
      stdout.write(line + '\n');
    }

    var stdErrLineStream =
        process.stderr.transform(Utf8Decoder()).transform(LineSplitter());
    await for (var line in stdErrLineStream) {
      stderr.write(line + '\n');
    }

    var exitCode = await process.exitCode;
    if (exitCode != 0)
      throw 'command failed: cmd=\'$cmd ${arguments.join(" ")}\'';
  }
}

/// Create list of simulators with their ID and status.
Map<String, Map<String, String>> simulatorsx() {
  String simulatorInfo = cmd('xcrun', ['simctl', 'list', 'devices'], '.', true);
  RegExp regExp = new RegExp(r'^    (.*) \((.*-.*-.*-.*)\) \((.*)\).*$',
      caseSensitive: false, multiLine: true);
  Iterable<Match> matches = regExp.allMatches(simulatorInfo);

  Map<String, Map<String, String>> simulators = {};
  for (Match m in matches) {
    // load into map
    Map<String, String> simulatorProps = {};
    simulatorProps['id'] = m.group(2);
    simulatorProps['status'] = m.group(3);
    simulators[m.group(1)] = simulatorProps;
  }
  return simulators;
}

/// Creates a list of available iOS devices.
/// (really just concerned with simulators for now).
/// Provides access to their IDs and status'.
Map getIosDevices() {
  final deviceInfoRaw =
      cmd('xcrun', ['simctl', 'list', 'devices', '--json'], '.', true);
  final deviceInfo = jsonDecode(deviceInfoRaw)['devices'];

  // transform json to a Map of device name by a map of iOS versions by a list of
  // devices with a map of properties
  // ie, Map<String, Map<String, List<Map<String, String>>>>
  // In other words, just pop-out the device name for 'easier' access to
  // the device properties.
  Map deviceInfoTransformed = {};

  deviceInfo.forEach((iOSVersionName, devices) {
//    print('iOSVersionName=$iOSVersionName');
    for (var device in devices) {
//      print('device=$device');
      // init iOS versions map if not already present
      if (deviceInfoTransformed[device['name']] == null) {
        deviceInfoTransformed[device['name']] = {};
      }

      // init iOS version device array if not already present
      // note: there can be multiple versions of a device with the same name
      //       for an iOS version, hence the use of an array.
      if (deviceInfoTransformed[device['name']][iOSVersionName] == null) {
        deviceInfoTransformed[device['name']][iOSVersionName] = [];
      }

      // add device to iOS version device array
      // ignoring devices that are not available
      if (device['availability'] == '(available)')
        deviceInfoTransformed[device['name']][iOSVersionName].add(device);
    }
  });
  return deviceInfoTransformed;
}

// finds the iOS device with the highest available iOS version
Map getHighestIosDevice(Map iosDevices, String deviceName) {
  final Map iOSVersions = iosDevices[deviceName];

  // sort keys in iOS version order (just in case)
  final iosVersionKeys = iOSVersions.keys.toList();
//  print('keys=$iosVersionKeys');
  iosVersionKeys.sort((v1, v2) {
    return v1.compareTo(v2);
  });

  final iOSVersionName = iosVersionKeys.last;
  // use the first device found for the iOS version
  return iosDevices[deviceName][iOSVersionName][0];
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

bool isAnyDeviceRunning() {
  return !cmd('flutter', ['devices'], '.', true)
      .contains('No devices detected.');
}
