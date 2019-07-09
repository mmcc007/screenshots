import 'dart:async';
import 'dart:io';

import 'package:resource/resource.dart';
import 'run.dart';

///
/// Copy resource images for a screen from package to files.
///
Future unpackImages(Map screenResources, String dstDir) async {
  for (String resourcePath in screenResources.values) {
    List<int> resourceImage = await readResourceImage(resourcePath);

    // create resource file
    final dstPath = '$dstDir/$resourcePath';
    await writeImage(resourceImage, dstPath);
  }
}

/// Read scripts from resources and install in staging area.
Future<void> unpackScripts(String dstDir) async {
  await unpackScript(
    'resources/script/android-wait-for-emulator',
    dstDir,
  );
  await unpackScript(
    'resources/script/android-wait-for-emulator-to-stop',
    dstDir,
  );
  await unpackScript(
    'resources/script/simulator-controller',
    dstDir,
  );
}

/// Read script from resources and install in staging area.
Future unpackScript(String srcPath, String dstDir) async {
  final resource = Resource('package:screenshots/$srcPath');
  final String script = await resource.readAsString();
  final file = await File('$dstDir/$srcPath').create(recursive: true);
  await file.writeAsString(script, flush: true);
  // make executable
  cmd('chmod', ['u+x', '$dstDir/$srcPath']);
}

/// Read an image from resources.
Future<List<int>> readResourceImage(String uri) async {
  final resource = Resource('package:screenshots/$uri');
  return resource.readAsBytes();
}

/// Write an image to staging area.
Future<void> writeImage(List<int> image, String path) async {
  final file = await File(path).create(recursive: true);
  await file.writeAsBytes(image, flush: true);
}
