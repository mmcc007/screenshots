import 'dart:io';

import 'package:resource/resource.dart';
import 'package:screenshots/utils.dart';

///
/// Copy resource images for a screen from package to files.
///
Future unpackImages(Map screenResources, String stagingPath) async {
  print('unpacking resources=$screenResources');

  for (String screenResource in screenResources.values) {
    print('uri=package:screenshots/$screenResource');
    List<int> resourceImage = await readImage(screenResource);

    // create resource file
    final resourcePath = '$stagingPath/$screenResource';
    print('resourcePath=$resourcePath');
    await writeImage(resourceImage, resourcePath);
  }
}

/// Read script from resources and install in staging area.
Future unpackScript(String stagingPath) async {
  final path = 'resources/script/android-wait-for-emulator-to-stop';
  var resource = Resource('package:screenshots/$path');
  final String script = await resource.readAsString();
  print('script=$script');
  final file = await File('$stagingPath/$path').create(recursive: true);
  await file.writeAsString(script, flush: true);
  // make executable
  cmd('chmod', ['u+x', '$stagingPath/$path']);
}
//Future<String> sampleTxt() async {
//  var resource = const Resource('package:screenshots/resources/sample.txt');
//  return resource.readAsString();
//}
//
//Future<List<int>> sampleImage() async {
////  var resource = const Resource('package:screenshots/resources/sample.png');
////  return resource.readAsBytes();
//  return readImage('resources/sample.png');
//}

/// Read an image from resources.
Future<List<int>> readImage(String uri) async {
  var resource = Resource('package:screenshots/$uri');
  return resource.readAsBytes();
}

/// Write an image to staging area.
Future<void> writeImage(List<int> image, String path) async {
  final file = await File(path).create(recursive: true);
  await file.writeAsBytes(image, flush: true);
}
