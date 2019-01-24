import 'dart:io';

import 'package:file_utils/file_utils.dart';

///
/// Remove all content from directory [dir].
///
void clearDirectory(String dir) {
  print('clearing $dir');
//  if (!(FileUtils.rm([dir], directory: true, force: true, recursive: true) &&
//      FileUtils.mkdir([dir], recursive: true))) {
//    throw 'clear directory failed: dir=$dir';
//  }
  if (Directory(dir).existsSync()) Directory(dir).deleteSync(recursive: true);
}

/// Move directory [srcDir] to [dstDir].
void moveDirectory(String srcDir, String dstDir) {
  if (!(FileUtils.mkdir([dstDir], recursive: true) &&
      FileUtils.move(['$srcDir/*.*'], dstDir))) {
    throw 'move directory failed: srcDir=$srcDir, destDir=$dstDir';
  }
}

/// Returns list of files in directory [dir].
Future<List<File>> filesInDirectory(Directory dir) async {
  List<File> files = <File>[];
  await for (FileSystemEntity entity
      in dir.list(recursive: false, followLinks: false)) {
    FileSystemEntityType type = await FileSystemEntity.type(entity.path);
    if (type == FileSystemEntityType.file) {
      files.add(entity);
      print(entity.path);
    }
  }
  return files;
}

//bool isSymlink(String pathString) {
//  var path = new Path(pathString);
//
//  var parentPath = path.directoryPath;
//  var fullParentPath = new File.fromPath(parentPath).fullPathSync();
//  var expectedPath = new Path(fullParentPath).append(path.filename).toString();
//
//  var fullPath = new File.fromPath(path).fullPathSync();
//
//  return fullPath != expectedPath;
//}

/// Copy directory [path1] to [path2].
void copyDir(String path1, String path2) {
  Directory dir1 = new Directory(path1);
  if (!dir1.existsSync()) {
    throw new Exception(
        'Source directory "${dir1.path}" does not exist, nothing to copy');
  }
  Directory dir2 = new Directory(path2);
  if (!dir2.existsSync()) {
    dir2.createSync(recursive: true);
  }

  dir1.listSync().forEach((element) {
//    if (!isSymlink(element.path)) {
//    Path elementPath = new Path(element.path);
//    String newPath = "${dir2.path}/${elementPath.filename}";
    if (element is File) {
//      File newFile = new File(newPath);
      File newFile = new File(element.toString());
      newFile.writeAsBytesSync(element.readAsBytesSync());
//    } else if (element is Directory) {
//      recursiveFolderCopySync(element.path, newPath);
//    } else {
//      throw new Exception('File is neither File nor Directory. HOW?!');
    }
//    }
  });
}

/// Execute command [cmd] with arguments [arguments] in a separate process and return stdout.
String cmd(String cmd, List<String> arguments,
    [String workingDir = '.', bool silent = false]) {
  print('cmd=\'$cmd ${arguments.join(" ")}\'');
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

///
/// Create list of simulators with their ID and status.
///
Map<String, Map<String, String>> simulators() {
  String devices = cmd('xcrun', ['simctl', 'list'], '.', true);
//     print ('devices=$devices');
  RegExp regExp = new RegExp(r'^    (.*) \((.*-.*-.*-.*)\) \((.*)\)$',
      caseSensitive: false, multiLine: true);
  Iterable<Match> matches = regExp.allMatches(devices);
//    matches.forEach((match){
//      print('match=$match');
//    });
  Map<String, Map<String, String>> simulators = {};
  for (Match m in matches) {
//    String match = m.group(0);
//    print(match);
//    print(m.group(1));
//    print(m.group(2));
//    print(m.group(3));
    // load into map
    Map<String, String> simulatorInfo = {};
    simulatorInfo['id'] = m.group(2);
    simulatorInfo['status'] = m.group(3);
    simulators[m.group(1)] = simulatorInfo;
  }
  return simulators;
}

//List<dynamic> mapKeysToList(Map<dynamic, dynamic> map) {
//  return map.values;
//}
