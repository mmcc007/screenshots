import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:screenshots/src/utils.dart';

///// Test for CI environment.
//bool     true   {
//  return LocalPlatform().environment['CI']?.toLowerCase() == 'true';
//}

/// Copy files from [srcDir] to [dstDir].
/// If dstDir does not exist, it is created.
void copyFiles(String srcDir, String dstDir) {
  if (!Directory(dstDir).existsSync()) {
    Directory(dstDir).createSync(recursive: true);
  }
  Directory(srcDir).listSync().forEach((file) {
    file.statSync().type == FileSystemEntityType.file
        ? File(file.path).copy('$dstDir/${p.basename(file.path)}')
        : throw 'Error: ${file.path} is not a file';
  });
}

/// Clear a named directory if it exists.
/// Create directory if none exists.
void clearDirectory(String dir) {
  _deleteDir(dir);
  Directory(dir).createSync(recursive: true);
}

/// Delete a directory if it exists.
void _deleteDir(String dir) {
  if (Directory(dir).existsSync()) {
    Directory(dir).deleteSync(recursive: true);
  }
}

/// Get device properties
Map getDeviceProps(String deviceId) {
  final props = {};
  cmd(['adb', '-s', deviceId, 'shell', 'getprop'])
      .trim()
      .split('\n')
      .forEach((line) {
    final regExp = RegExp(r'\[(.*)\]: \[(.*)\]');
    var match = regExp.firstMatch(line)!;
    final key = match.group(1);
    final val = match.group(2);
    props[key] = val;
  });
  return props;
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
  Timer? _timer;

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

/// Show differences between maps
Map diffMaps(Map orig, Map diff, {bool verbose = false}) {
  var diffs = <String, dynamic>{
    'added': {},
    'removed': {},
    'changed': {'orig': {}, 'new': {}}
  };
  diff.forEach((k, v) {
    if (orig[k] == null) {
      if (verbose) print('$k : \'$v\' added');
      diffs['added'][k] = v;
    }
  });
  orig.forEach((k, v) {
    if (diff[k] == null) {
      if (verbose) print('$k : \'$v\' removed');
      diffs['removed'][k] = v;
    }
  });
  orig.forEach((k, v) {
    if (diff[k] != null && diff[k] != v) {
      if (verbose) print('$k : \'$v\'=>\'${diff[k]}\'');
      diffs['changed']['orig'][k] = v;
      diffs['changed']['new'][k] = diff[k];
    }
  });
  return diffs;
}

/// Returns a future that completes with a path suitable for ANDROID_HOME
/// or with null, if ANDROID_HOME cannot be found.
Future<String?> findAndroidHome() async {
  final hits = grep(
    'ANDROID_HOME = ',
    from: cmd(<String>['flutter', 'doctor', '-v']),
  );
  if (hits.isEmpty) return null;
  return hits.first.split('= ').last;
}

/// Splits [from] into lines and selects those that contain [pattern].
Iterable<String> grep(Pattern pattern, {required String from}) {
  return from.split('\n').where((String line) {
    return line.contains(pattern);
  });
}

///// Wait for android emulator to stop.
//Future<void> waitAndroidEmulatorShutdown(String deviceId) async {
//  int timeout = 100;
//  final pollingInterval = 500;
//  final notFound = 'not found';
//  String bootCompleted =
//      ''; // possible values 1/0 ignored, depending on failed adb command
//  AsyncCallback getEmulatorStatus = () async {
//    // expects a local status var
//    bootCompleted = cmd(
//            'sh',
//            [
//              '-c',
//              'adb -s $deviceId -e shell getprop sys.boot_completed || echo \"$notFound\"'
//            ],
//            '.',
//            true)
//        .trim();
//  };
//  final poller =
//      Poller(getEmulatorStatus, Duration(milliseconds: pollingInterval));
//
//  while (bootCompleted != notFound && timeout > 0) {
//    await Future.delayed(Duration(milliseconds: pollingInterval));
//    timeout -= 1;
//  }
//  if (timeout == 0) throw 'Error: shutdown timed-out.';
//  poller.cancel();
//}

//Future<void> waitAndroidLocaleChange(String deviceId) async {
//  //ro.product.locale ==> DEFAULT LOCALE??
//  int timeout = 100;
//  final pollingInterval = 500;
//  Map previousAdbProps = getDeviceProps(deviceId);
//
//  AsyncCallback reportProps = () async {
//    print('Checking for prop changes...');
//    Map newAdbProps = getDeviceProps(deviceId);
//    diffMaps(previousAdbProps, newAdbProps, verbose: true);
//    previousAdbProps = newAdbProps;
//  };
//  final propsPoller =
//      Poller(reportProps, Duration(milliseconds: pollingInterval));
//
//  String bootAnimStatus = '';
//  AsyncCallback getBootAnimStatus = () async {
//    // expects a local status var
//    bootAnimStatus = cmd(
//            'sh',
//            ['-c', 'adb -s $deviceId shell getprop init.svc.zygote'],
////            ['-c', 'adb -s $deviceId shell getprop sys.boot_completed'],
//            '.',
//            true)
//        .trim();
//  };
//  await getBootAnimStatus();
//  final origBootAnimStatus = bootAnimStatus;
//  print('origBootAnimStatus=$origBootAnimStatus');
//  await Future.delayed(Duration(milliseconds: 40000));
//  print('Starting poller');
//  final poller =
//      Poller(getBootAnimStatus, Duration(milliseconds: pollingInterval));
//
//  while ((bootAnimStatus == 'stopping' || bootAnimStatus == 'restarting') &&
//      timeout > 0) {
//    print(
//        'Waiting for locale change to complete: status: $bootAnimStatus, timeout=$timeout');
//    await Future.delayed(Duration(milliseconds: pollingInterval));
//    timeout -= 1;
//  }
//  if (timeout == 0) throw 'Error: locale change timed-out.';
//  poller.cancel();
//  propsPoller.cancel();
//  print(
//      'locale changed during bootAnim change from $origBootAnimStatus to $bootAnimStatus');
//}

///// Clear directory [dirPath].
///// Create directory if none exists.
//void clearDirectory(String dirPath) {
//  if (Directory(dirPath).existsSync()) {
//    Directory(dirPath).deleteSync(recursive: true);
//  } else {
//    Directory(dirPath).createSync(recursive: true);
//  }
//}
