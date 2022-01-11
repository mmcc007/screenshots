import 'dart:async';
import 'dart:io';

import 'config.dart';
import 'globals.dart';

/// Called by integration test to capture images.
Future screenshot(final driver, Config config, String name,
    {Duration timeout = const Duration(seconds: 30),
    bool silent = false,
    bool waitUntilNoTransientCallbacks = true}) async {
  if (waitUntilNoTransientCallbacks) {
    await driver.waitUntilNoTransientCallbacks(timeout: timeout);
  }

  final pixels = await driver.screenshot();
  final testDir = '${config.stagingDir}/$kTestScreenshotsDir';
  final file =
  await File('$testDir/$name.$kImageExtension').create(recursive: true);
  await file.writeAsBytes(pixels);
  if (!silent) print('Screenshot $name created');
}
