import 'dart:async';
import 'dart:io';

import 'package:file_utils/file_utils.dart';
import 'package:path/path.dart';

/// Clear directory [dir].
void clearDirectory(String dir) {
//  if (!(FileUtils.rm([dir], directory: true, force: true, recursive: true) &&
//      FileUtils.mkdir([dir], recursive: true))) {
//    throw 'clear directory failed: dir=$dir';
//  }
  if (Directory(dir).existsSync()) {
    Directory(dir).deleteSync(recursive: true);
  }
  Directory(dir).createSync(recursive: true);
}

/// Move directory [srcDir] to [dstDir].
void moveDirectory(String srcDir, String dstDir) {
  if (!(FileUtils.mkdir([dstDir], recursive: true) &&
      FileUtils.move(['$srcDir/*.*'], dstDir))) {
    throw 'move directory failed: srcDir=$srcDir, destDir=$dstDir';
  }
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
    await file.rename(dirname(file.path) + '/' + prefix + basename(file.path));
  }
}

//List<File> filesInDirectory(Directory dir) async {
//  List<File> files = <File>[];
//  await for (FileSystemEntity entity in dir.list(recursive: false, followLinks: false)) {
//    FileSystemEntityType type = await FileSystemEntity.type(entity.path);
//    if (type == FileSystemEntityType.FILE) {
//      files.add(entity);
//      print(entity.path);
//    }
//  }
//  return files;
//}
