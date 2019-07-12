import 'dart:async';
import 'dart:io';

import 'globals.dart';

///
/// Called by integration test to capture images.
///
Future screenshot(final driver, Map config, String name,
    {Duration timeout = const Duration(seconds: 30)}) async {
  // todo: auto-naming scheme
  await driver.waitUntilNoTransientCallbacks(timeout: timeout);
  final List<int> pixels = await driver.screenshot();
  final stagingDir = '${config['staging']}/test';
  final File file = await File('$stagingDir/$name.$kImageExtension').create(recursive: true);
  await file.writeAsBytes(pixels);
  print('Screenshot $name created');
}
