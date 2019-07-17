import 'dart:async';
import 'dart:io';

import 'package:meta/meta.dart';

import 'archive.dart';
import 'screens.dart';
import 'fastlane.dart' as fastlane;
import 'resources.dart' as resources;
import 'utils.dart' as utils;
import 'package:path/path.dart' as p;

import 'globals.dart';

class ImageProcessor {
  static const kDefaultIosBackground = 'xc:white';
  static const kDefaultAndroidBackground = 'xc:none'; // transparent
  static const kCrop =
      '1000x40+0+0'; // default sample size and location to test for brightness

  final Screens _screens;
  final Map _config;
  ImageProcessor(Screens screens, Map config)
      : _screens = screens,
        _config = config;

  /// Process screenshots.
  ///
  /// If android, screenshot is overlaid with a status bar and appended with
  /// a navbar.
  ///
  /// If ios, screenshot is overlaid with a status bar.
  ///
  /// If 'frame' in config file is true, screenshots are placed within image of device.
  ///
  /// After processing, screenshots are handed off for upload via fastlane.
  Future<void> process(DeviceType deviceType, String deviceName, String locale,
      RunMode runMode, Archive archive) async {
    final Map screenProps = _screens.screenProps(deviceName);
    if (screenProps == null) {
      print('Warning: \'$deviceName\' images will not be processed');
    } else {
      final Map screenResources = screenProps['resources'];
      final staging = _config['staging'];
//  print('screenResources=$screenResources');
      print('Processing screenshots from test...');

      // unpack images for screen from package to local staging area
      await resources.unpackImages(screenResources, staging);

      // add status and nav bar and frame for each screenshot
      final screenshots = Directory('$staging/$kTestScreenshotsDir').listSync();
      for (final screenshotPath in screenshots) {
        // add status bar for each screenshot
//    print('overlaying status bar over screenshot at $screenshotPath');
        await overlay(_config, screenResources, screenshotPath.path);

        if (deviceType == DeviceType.android) {
          // add nav bar for each screenshot
//      print('appending navigation bar to screenshot at $screenshotPath');
          await append(_config, screenResources, screenshotPath.path);
        }

        // add frame if required
        if (isFrameRequired(_config, deviceType, deviceName)) {
//      print('placing $screenshotPath in frame');
          await frame(_config, screenProps, screenshotPath.path, deviceType, runMode);
        }
      }
    }

    // move to final destination for upload to stores via fastlane
    final srcDir = '${_config['staging']}/$kTestScreenshotsDir';
    final androidModelType = fastlane.getAndroidModelType(screenProps);
    String dstDir = fastlane.getDirPath(deviceType, locale, androidModelType);
    runMode == RunMode.recording
        ? dstDir = '${_config['recording']}/$dstDir'
        : null;
    runMode == RunMode.archive
        ? dstDir = archive.dstDir(deviceType, locale)
        : null;
    // prefix screenshots with name of device before moving
    // (useful for uploading to apple via fastlane)
    await utils.prefixFilesInDir(srcDir, '$deviceName-');

    print('Moving screenshots to $dstDir');
    utils.moveFiles(srcDir, dstDir);

    if (runMode == RunMode.comparison) {
      final recordingDir = '${_config['recording']}/$dstDir';
      print(
          'Running comparison with recorded screenshots in $recordingDir ...');
      final failedCompare =
          await compareImages(deviceName, recordingDir, dstDir);
      if (failedCompare.isNotEmpty) {
        showFailedCompare(failedCompare);
        throw 'Error: comparison failed.';
      }
    }
  }

  @visibleForTesting
  void showFailedCompare(Map failedCompare) {
    stderr.writeln('Error: comparison failed:');

    failedCompare.forEach((screenshotName, result) {
      stderr.writeln(
          'Error: ${result['comparison']} is not equal to ${result['recording']}');
      stderr.writeln('       Differences can be found in ${result['diff']}');
    });
  }

  @visibleForTesting
  Future<Map> compareImages(
      String deviceName, String recordingDir, String comparisonDir) async {
    Map failedCompare = {};
    final recordedImages = Directory(recordingDir).listSync();
    Directory(comparisonDir)
        .listSync()
        .where((screenshot) =>
            p.basename(screenshot.path).contains(deviceName) &&
            !p.basename(screenshot.path).contains(im.diffSuffix))
        .forEach((screenshot) {
      final screenshotName = p.basename(screenshot.path);
      final recordedImageEntity = recordedImages.firstWhere(
          (image) => p.basename(image.path) == screenshotName,
          orElse: () =>
              throw 'Error: screenshot $screenshotName not found in $recordingDir');

      if (!im.compare(screenshot.path, recordedImageEntity.path)) {
        failedCompare[screenshotName] = {
          'recording': recordedImageEntity.path,
          'comparison': screenshot.path,
          'diff': im.getDiffName(screenshot.path)
        };
      }
    });
    return failedCompare;
  }

  /// Overlay status bar over screenshot.
  Future overlay(Map config, Map screenResources, String screenshotPath) async {
    // if no status bar skip
    // todo: get missing status bars
    if (screenResources['statusbar'] == null) {
      print(
          'error: image ${p.basename(screenshotPath)} is missing status bar.');
      return Future.value(null);
    }

    String statusbarPath;
    // select black or white status bar based on brightness of area to be overlaid
    // todo: add black and white status bars
    if (im.thresholdExceeded(screenshotPath, kCrop)) {
      // use black status bar
      statusbarPath =
          '${config['staging']}/${screenResources['statusbar black']}';
    } else {
      // use white status bar
      statusbarPath =
          '${config['staging']}/${screenResources['statusbar white']}';
    }

    final options = {
      'screenshotPath': screenshotPath,
      'statusbarPath': statusbarPath,
    };
    await im.convert('overlay', options);
  }

  /// Append android navigation bar to screenshot.
  Future append(Map config, Map screenResources, String screenshotPath) async {
    final screenshotNavbarPath =
        '${config['staging']}/${screenResources['navbar']}';
    final options = {
      'screenshotPath': screenshotPath,
      'screenshotNavbarPath': screenshotNavbarPath,
    };
    await im.convert('append', options);
  }

  /// Checks if frame is required for [deviceName].
  static bool isFrameRequired(
      Map config, DeviceType deviceType, String deviceName) {
    final devices = config['devices'][utils.getStringFromEnum(deviceType)];
    final deviceKey =
        devices.keys.firstWhere((key) => key == deviceName, orElse: () => null);
    if (deviceKey == null) throw 'Error: device \'$deviceName\' not found';
    final device = devices[deviceName];
    bool isFrameRequired = config['frame'];
    if (device != null) {
      final isDeviceFrameRequired = device['frame'];
      if (isDeviceFrameRequired != null) {
        isFrameRequired = isDeviceFrameRequired;
      }
    }
    return isFrameRequired;
  }

  /// Frame a screenshot with image of device.
  ///
  /// Resulting image is scaled to fit dimensions required by stores.
  void frame(Map config, Map screen, String screenshotPath,
      DeviceType deviceType, RunMode runMode) async {
    final Map resources = screen['resources'];

    final framePath = config['staging'] + '/' + resources['frame'];
    final size = screen['size'];
    final resize = screen['resize'];
    final offset = screen['offset'];

    // set the default background color
    String backgroundColor;
    (deviceType == DeviceType.ios && runMode!=RunMode.archive)
        ? backgroundColor = kDefaultIosBackground
        : backgroundColor = kDefaultAndroidBackground;

    final options = {
      'framePath': framePath,
      'size': size,
      'resize': resize,
      'offset': offset,
      'screenshotPath': screenshotPath,
      'backgroundColor': backgroundColor,
    };
    await im.convert('frame', options);
  }
}
