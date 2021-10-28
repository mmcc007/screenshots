import 'dart:async';

import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:screenshots/src/config.dart';
import 'package:screenshots/src/image_magick.dart';
import 'package:screenshots/src/orientation.dart';
import 'package:tool_base/tool_base.dart' hide Config;

import 'archive.dart';
import 'fastlane.dart' as fastlane;
import 'globals.dart';
import 'resources.dart';
import 'screens.dart';
import 'utils.dart' as utils;

class ImageProcessor {
  static const _kDefaultIosBackground = 'xc:white';
  @visibleForTesting // for now
  static const kDefaultAndroidBackground = 'xc:none'; // transparent
  static const _kCrop =
      '1000x40+0+0'; // default sample size and location to test for brightness

  static const Screens _screens = Screens();
  final Config _config;

  const ImageProcessor(Config config) : _config = config;

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
  Future<bool> process(
    ConfigDevice device,
    String locale,
    Orientation? orientation,
    RunMode runMode,
    Archive? archive,
  ) async {
    final screenProps = _screens.getScreen(device.name);
    final screenshotsDir = '${_config.stagingDir}/$kTestScreenshotsDir';
    final screenshotPaths = fs.directory(screenshotsDir).listSync();
    if (screenProps == null) {
      printStatus("Warning: '${device.name}' images will not be processed");
    } else {
      // add frame if required
      if (device.isFrameRequired(orientation)) {
        final status = logger.startProgress(
            'Processing screenshots from test...',
            timeout: Duration(minutes: 4));

        // unpack images for screen from package to local tmpDir area
        var paths = await unpackImages(screenProps, _config.stagingDir);

        // add status and nav bar and frame for each screenshot
        if (screenshotPaths.isEmpty) {
          printStatus('Warning: no screenshots found in $screenshotsDir');
        }
        for (final screenshotPath in screenshotPaths) {
          // add status bar for each screenshot
          await overlay(_config.stagingDir, paths, screenshotPath.path);

          if (device.deviceType == DeviceType.android) {
            // add nav bar for each screenshot
            await append(_config.stagingDir, paths, screenshotPath.path);
          }

          await frame(_config.stagingDir, screenProps, paths,
              screenshotPath.path, device.deviceType, runMode);
        }
        status.stop();
      } else {
        printStatus('Warning: framing is not enabled');
      }
    }

    // move to final destination for upload to stores via fastlane
    if (screenshotPaths.isNotEmpty) {
      final androidModelType =
          fastlane.getAndroidModelType(screenProps, device.name);
      var dstDir = fastlane.getDirPath(device.deviceType, locale, androidModelType);
      runMode == RunMode.recording
          ? dstDir = '${_config.recordingDir!}/$dstDir'
          : null;
      runMode == RunMode.archive
          ? dstDir = archive!.dstDir(device.deviceType, locale)
          : null;
      // prefix screenshots with name of device before moving
      // (useful for uploading to apple via fastlane)
      await utils.prefixFilesInDir(screenshotsDir,
          '${device.name}-${orientation == null ? kDefaultOrientation : utils.getStringFromEnum(orientation)}-');

      printStatus('Moving screenshots to $dstDir');
      utils.moveFiles(screenshotsDir, dstDir);

      if (runMode == RunMode.comparison) {
        final recordingDir = '${_config.recordingDir!}/$dstDir';
        printStatus(
            'Running comparison with recorded screenshots in $recordingDir ...');
        final failedCompare =
            await compareImages(device.name, recordingDir, dstDir);
        if (failedCompare.isNotEmpty) {
          showFailedCompare(failedCompare);
          throw 'Error: comparison failed.';
        }
      }
    }
    return true; // for testing
  }

  @visibleForTesting
  static void showFailedCompare(Map failedCompare) {
    printError('Comparison failed:');

    failedCompare.forEach((screenshotName, result) {
      printError(
          '${result['comparison']} is not equal to ${result['recording']}');
      printError('       Differences can be found in ${result['diff']}');
    });
  }

  @visibleForTesting
  static Future<Map> compareImages(
      String deviceName, String recordingDir, String comparisonDir) async {
    var failedCompare = {};
    final recordedImages = fs.directory(recordingDir).listSync();
    fs
        .directory(comparisonDir)
        .listSync()
        .where((screenshot) =>
            p.basename(screenshot.path).contains(deviceName) &&
            !p.basename(screenshot.path).contains(ImageMagick.kDiffSuffix))
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
          'diff': im.getDiffImagePath(screenshot.path)
        };
      }
    });
    return failedCompare;
  }

  /// Overlay status bar over screenshot.
  static Future<void> overlay(
      String tmpDir, ScreenImagePaths paths, String screenshotPath) async {
    // if no status bar skip
    // todo: get missing status bars
    if (paths.statusbar == null) {
      printStatus(
          'error: image ${p.basename(screenshotPath)} is missing status bar.');
      return;
    }

    File statusbarPath;
    // select black or white status bar based on brightness of area to be overlaid
    // todo: add black and white status bars
    if (im.isThresholdExceeded(screenshotPath, _kCrop)) {
      // use black status bar
      statusbarPath = paths.statusbarBlack!;
    } else {
      // use white status bar
      statusbarPath = paths.statusbarWhite!;
    }

    final options = {
      'screenshotPath': screenshotPath,
      'statusbarPath': statusbarPath,
    };
    await im.convert('overlay', options);
  }

  /// Append android navigation bar to screenshot.
  static Future<void> append(
      String tmpDir, ScreenImagePaths paths, String screenshotPath) async {
    final screenshotNavbarPath = '$tmpDir/${paths.navbar}';
    final options = {
      'screenshotPath': screenshotPath,
      'screenshotNavbarPath': screenshotNavbarPath,
    };
    await im.convert('append', options);
  }

  /// Frame a screenshot with image of device.
  ///
  /// Resulting image is scaled to fit dimensions required by stores.
  static Future<void> frame(
      String tmpDir,
      ScreenInfo info,
      ScreenImagePaths paths,
      String screenshotPath,
      DeviceType deviceType,
      RunMode runMode) async {
    // set the default background color
    var backgroundColor =
        deviceType == DeviceType.ios && runMode != RunMode.archive
            ? _kDefaultIosBackground
            : kDefaultAndroidBackground;

    final options = {
      'framePath': tmpDir + '/' + paths.frame!.path,
      'size': info.size,
      'resize': info.resize,
      'offset': info.offset,
      'screenshotPath': screenshotPath,
      'backgroundColor': backgroundColor,
    };
    await im.convert('frame', options);
  }
}
