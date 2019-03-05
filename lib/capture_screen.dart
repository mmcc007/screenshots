import 'dart:async';
import 'dart:io';

///
/// Called by integration test to capture images.
///
Future screenshot(final driver, Map config, String name,
    [Duration timeout = const Duration(seconds: 5)]) async {
  // todo: auto-naming scheme
  final stagingDir = config['staging'] + '/test';
  await driver.waitUntilNoTransientCallbacks(timeout: timeout);
  final List<int> pixels = await driver.screenshot();
  final File file =
      await File(stagingDir + '/' + name + '.png').create(recursive: true);
  await file.writeAsBytes(pixels);
  print('Screenshot $name created');
}
