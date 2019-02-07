import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Clear directory [dir].
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

/// Execute command [cmd] with arguments [arguments] in a separate process and return stdout.
///
/// If [silent] is false, output to stdout.
String cmd(String cmd, List<String> arguments,
    [String workingDir = '.', bool silent = false]) {
//  print('cmd=\'$cmd ${arguments.join(" ")}\'');
  final result = Process.runSync(cmd, arguments, workingDirectory: workingDir);
  if (!silent) stdout.write(result.stdout);
  if (result.exitCode != 0) {
//    stdout.write(result.stdout);
    stderr.write(result.stderr);
//    exit(result.exitCode);
    throw 'command failed: cmd=\'$cmd ${arguments.join(" ")}\'';
  }
  return result.stdout;
}

/// Execute command [cmd] with arguments [arguments] in a separate process and stream stdout/stderr.
Future<void> streamCmd(String cmd, List<String> arguments) async {
//  print('cmd=\'$cmd ${arguments.join(" ")}\'');

  final process = await Process.start(cmd, arguments);

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

/// Create list of simulators with their ID and status.
Map<String, Map<String, String>> simulators() {
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

/// Create list of emulators
List<String> emulators() {
  return cmd('emulator', ['-list-avds'], '.', true).split('\n');
}

/// Adds prefix to all files in a directory
Future prefixFilesInDir(String dirPath, String prefix) async {
  await for (final file
      in Directory(dirPath).list(recursive: false, followLinks: false)) {
    await file
        .rename(p.dirname(file.path) + '/' + prefix + p.basename(file.path));
  }
}
