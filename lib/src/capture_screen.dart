import 'dart:async';
import 'dart:io';

import 'config.dart';
import 'globals.dart';
import 'utils.dart' as utils;

/// Called by integration test to capture images.
Future screenshot(final driver, Config config, String name,
    {Duration timeout = const Duration(seconds: 30),
    bool silent = false,
    bool waitUntilNoTransientCallbacks = true}) async {
  if (config.isScreenShotsAvailable) {
    // todo: auto-naming scheme
    final testDir = '${config.stagingDir}/$kTestScreenshotsDir';
    final fileLocationAdb = await File('$testDir/$name.adb.$kImageExtension');
    final fileLocationDriver = await File('$testDir/$name.driver.$kImageExtension');

    final env = await config.screenshotsEnv;   
    if(env.containsKey('adb_path') && env.containsKey('adb_device_id') && env.containsKey('device_type') && env['device_type'] == 'android'){
      try {
        await _takeScreenshotUsingAdb(fileLocationAdb, env['adb_path'], env['adb_device_id']);
      } catch (e) {
        if(!silent) print('Warning: Failed to take screenshot $name using adb. Using FlutterDriver as fallback method.');
        if(await fileLocationAdb.exists()) await fileLocationAdb.delete();
        await _takeScreenshotUsingFlutterDriver(fileLocationDriver, driver, timeout, waitUntilNoTransientCallbacks);
      }
    }else{
      await _takeScreenshotUsingFlutterDriver(fileLocationDriver, driver, timeout, waitUntilNoTransientCallbacks);
    }

    if (!silent) print('Screenshot $name created using ${await fileLocationAdb.exists() ? "adb" : "flutter driver"}');
  } else {
    if (!silent) print('Warning: screenshot $name not created');
  }
}

Future _takeScreenshotUsingAdb(File destination, String adbLocation, String deviceId) async {
  try {
    await destination.create(recursive: true);
    
    // Activate Demo Mode
    utils.cmd([adbLocation, '-s', deviceId, 'shell', 'settings', 'put', 'global', 'sysui_demo_allowed', '1'], trace: false);
    utils.cmd([adbLocation, '-s', deviceId, 'shell', 'am', 'broadcast', '-a', 'com.android.systemui.demo', '-e', 'command', 'enter'], trace: false);
    utils.cmd([adbLocation, '-s', deviceId, 'shell', 'am', 'broadcast', '-a', 'com.android.systemui.demo', '-e', 'command', 'clock', '-e', 'hhmm', '1600'], trace: false);
    utils.cmd([adbLocation, '-s', deviceId, 'shell', 'am', 'broadcast', '-a', 'com.android.systemui.demo', '-e', 'command', 'notifications', '-e', 'visible', 'false'], trace: false);
    utils.cmd([adbLocation, '-s', deviceId, 'shell', 'settings', 'put', 'global', 'sysui_demo_allowed', '1'], trace: false);

    // Take Screenshot
    final screenshotResult = await Process.run(adbLocation, ['-s', deviceId, 'exec-out', 'screencap', '-p'], stdoutEncoding: null);
    await destination.writeAsBytes(screenshotResult.stdout); 
  } finally {
    // Deactivate Demo Mode
    utils.cmd([adbLocation, '-s', deviceId, 'shell', 'am', 'broadcast', '-a', 'com.android.systemui.demo', '-e', 'command', 'exit'], trace: false);
  }
}

Future _takeScreenshotUsingFlutterDriver(File destination, driver, Duration timeout, bool waitUntilNoTransientCallbacks) async {
  await destination.create(recursive: true);
  if (waitUntilNoTransientCallbacks) {
    await driver.waitUntilNoTransientCallbacks(timeout: timeout);
  }
  final pixels = await driver.screenshot();
  await destination.writeAsBytes(pixels);
}
