// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:path/path.dart' show Context;
import 'package:platform/platform.dart';

const Map<String, String> _osToPathStyle = <String, String>{
  'linux': 'posix',
  'macos': 'posix',
  'android': 'posix',
  'ios': 'posix',
  'fuchsia': 'posix',
  'windows': 'windows',
};

///// Sanatizes the executable path on Windows.
///// https://github.com/dart-lang/sdk/issues/37751
//String sanitizeExecutablePath(String executable,
//    {Platform platform = const LocalPlatform()}) {
//  if (executable.isEmpty) {
//    return executable;
//  }
//  if (!platform.isWindows) {
//    return executable;
//  }
//  if (executable.contains(' ') && !executable.contains('"')) {
//    // Use quoted strings to indicate where the file name ends and the arguments begin;
//    // otherwise, the file name is ambiguous.
//    return '"$executable"';
//  }
//  return executable;
//}

/// Searches the `PATH` for the executable that [command] is supposed to launch.
///
/// This first builds a list of candidate paths where the executable may reside.
/// If [command] is already an absolute path, then the `PATH` environment
/// variable will not be consulted, and the specified absolute path will be the
/// only candidate that is considered.
///
/// Once the list of candidate paths has been constructed, this will pick the
/// first such path that represents an existent file.
///
/// Return `null` if there were no viable candidates, meaning the executable
/// could not be found.
///
/// If [platform] is not specified, it will default to the current platform.
String? getExecutablePath(
  String command,
  String? workingDirectory, {
  Platform platform = const LocalPlatform(),
  FileSystem fs = const LocalFileSystem(),
}) {
  assert(_osToPathStyle[platform.operatingSystem] == fs.path.style.name);

  workingDirectory ??= fs.currentDirectory.path;
  Context context = Context(style: fs.path.style, current: workingDirectory);

  // TODO(goderbauer): refactor when github.com/google/platform.dart/issues/2
  //     is available.
  String pathSeparator = platform.isWindows ? ';' : ':';

  List<String> extensions = <String>[];
  if (platform.isWindows && context.extension(command).isEmpty) {
    extensions = (platform.environment['PATHEXT'] ?? '').split(pathSeparator);
  }

  List<String> candidates = <String>[];
  if (command.contains(context.separator)) {
    candidates = _getCandidatePaths(
        command, [workingDirectory], extensions, context);
  } else {
    var searchPath = (platform.environment['PATH'] ?? '').split(pathSeparator);
    candidates = _getCandidatePaths(command, searchPath, extensions, context);
  }
  for (var path in candidates) {
    if(fs.file(path).existsSync()) {
      return path;
    }
  }
  return null;
}

/// Returns all possible combinations of `$searchPath\$command.$ext` for
/// `searchPath` in [searchPaths] and `ext` in [extensions].
///
/// If [extensions] is empty, it will just enumerate all
/// `$searchPath\$command`.
/// If [command] is an absolute path, it will just enumerate
/// `$command.$ext`.
List<String> _getCandidatePaths(
  String command,
  List<String> searchPaths,
  List<String> extensions,
  Context context,
) {
  var withExtensions = extensions.isNotEmpty
      ? extensions.map((String ext) => '$command$ext').toList()
      : <String>[command];
  if (context.isAbsolute(command)) {
    return withExtensions;
  }
  return searchPaths
      .map((String path) =>
          withExtensions.map((String command) => context.join(path, command)))
      .expand((Iterable<String> e) => e)
      .toList();
}
