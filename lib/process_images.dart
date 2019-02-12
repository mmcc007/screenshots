import 'dart:io';

import 'package:screenshots/screens.dart';
import 'package:screenshots/fastlane.dart' as fastlane;
import 'package:screenshots/image_magick.dart' as im;
import 'package:screenshots/resources.dart' as resources;
import 'package:screenshots/screenshots.dart';
import 'package:screenshots/utils.dart' as utils;
import 'package:path/path.dart' as p;

///
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
///
void process(Map screens, Map config, DeviceType deviceType, String deviceName,
    String locale) async {
  final Map screenProps = Screens().screenProps(screens, deviceName);
  final staging = config['staging'];
  final Map screenResources = screenProps['resources'];
//  print('screenResources=$screenResources');
  print('Processing screenshots from test...');

  // unpack images for screen from package to local staging area
  await resources.unpackImages(screenResources, staging);

  // add status and nav bar and frame for each screenshot
  final screenshots = Directory('$staging/test').listSync();
  for (final screenshotPath in screenshots) {
    // add status bar for each screenshot
//    print('overlaying status bar over screenshot at $screenshotPath');
    await overlay(config, screenResources, screenshotPath.path);

    if (deviceType == DeviceType.android) {
      // add nav bar for each screenshot
//      print('appending navigation bar to screenshot at $screenshotPath');
      await append(config, screenResources, screenshotPath.path);
    }

    // add frame if required
    if (config['frame']) {
//      print('placing $screenshotPath in frame');
      await frame(config, screenProps, screenshotPath.path);
    }
  }

  // move to final destination for upload to stores via fastlane
  final srcDir = '${config['staging']}/test';
  final dstDir = fastlane.path(deviceType, locale, '', screenProps['destName']);
  // prefix screenshots with name of device before moving
  // (useful for uploading to apple via fastlane)
  await utils.prefixFilesInDir(srcDir, '$deviceName-');

  print('Moving screenshots to $dstDir');
  utils.moveFiles(srcDir, dstDir);
}

///
/// Overlay status bar over screenshot.
///
Future overlay(Map config, Map screenResources, String screenshotPath) async {
  final statusbarPath = '${config['staging']}/${screenResources['statusbar']}';

  // if no status bar skip
  // todo: get missing status bars
  if (screenResources['statusbar'] == null) {
    print('error: image ${p.basename(screenshotPath)} is missing status bar.');
    return Future.value(null);
  }
  final options = {
    'screenshotPath': screenshotPath,
    'statusbarPath': statusbarPath,
  };
  await im.imagemagick('overlay', options);
}

///
/// Append android status bar to screenshot.
///
Future append(Map config, Map screenResources, String screenshotPath) async {
  final screenshotNavbarPath =
      '${config['staging']}/${screenResources['navbar']}';
  final options2 = {
    'screenshotPath': screenshotPath,
    'screenshotNavbarPath': screenshotNavbarPath,
  };
  await im.imagemagick('append', options2);
}

///
/// Frame a screenshot with image of device.
///
/// Resulting image is scaled to fit dimensions required by stores.
///
void frame(Map config, Map screen, String screenshotPath) async {
  final Map resources = screen['resources'];

  final framePath = config['staging'] + '/' + resources['frame'];
  final size = screen['size'];
  final resize = screen['resize'];
  final offset = screen['offset'];

  final options = {
    'framePath': framePath,
    'size': size,
    'resize': resize,
    'offset': offset,
    'screenshotPath': screenshotPath,
  };
  await im.imagemagick('frame', options);
}
