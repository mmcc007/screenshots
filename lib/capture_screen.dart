import 'dart:io';
//import 'package:flutter_driver/flutter_driver.dart';

///
/// Called by integration test to capture images
///
Future screenshot(var driver, Map config, String name) async {
  // todo: auto-naming scheme
  final stagingDir = config['staging'] + '/test';
  await driver.waitUntilNoTransientCallbacks();
  final List<int> pixels = await driver.screenshot();
  final File file =
      await File(stagingDir + '/' + name + '.png').create(recursive: true);
  await file.writeAsBytes(pixels);
  print('wrote $file');
}
