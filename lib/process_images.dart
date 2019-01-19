import 'package:file_utils/file_utils.dart';
import 'package:screenshots/devices.dart';
import 'package:screenshots/fastlane.dart' as fastlane;
import 'package:screenshots/image_magick.dart' as im;
import 'package:screenshots/resources.dart' as resources;
import 'package:screenshots/screenshots.dart';
import 'package:screenshots/utils.dart' as utils;
import 'package:yaml/yaml.dart';

///
/// Process screenshots
/// If android, screenshot is overlaid with a status bar and appended with
/// a navbar.
/// If 'config.frame' is true screenshots are placed within image of device.
/// After processing, screenshots are handed off for upload via fastlane
///
void process(YamlNode devices, Map config, DeviceType deviceType,
    String deviceName, String locale) async {
  final Map screen = Devices().screen(devices, deviceName);
  final staging = config['staging'];
  final Map screenResources = screen['resources'];
  print('resources=$screenResources');

  // unpack screen resources
//    List screenResourcesList = [];
//    screenResources.forEach((k, resource) {
//      screenResourcesList.add(resource);
//    });
//    print('screenResources=$screenResources');

  // unpack images for screen from package to local staging area
  await resources.unpackImages(screenResources, staging);

  // add status bar for each screenshot
//    List screenshots = FileUtils.glob('$staging/test/*.*');
//    for (final screenshotPath in screenshots) {
//      final statusbarPath = '${config['staging']}/${resources['statusbar']}';
//      final screenshotStatusbarPath =
//          '${config['staging']}/test/' + FileUtils.basename(screenshotPath);
//      final options = {
//        'screenshotPath': screenshotPath,
//        'statusbarPath': statusbarPath,
//        'screenshotStatusbarPath': screenshotStatusbarPath,
//      };
//      await imagemagick('overlay', options);
//    }

  // add status and nav bar and frame for each screenshot
  final screenshots = FileUtils.glob('$staging/test/*.*');
//    print('screenshots=$screenshots');
  for (final screenshotPath in screenshots) {
    // add status bar for each screenshot
    print('overlaying status bar over screenshot at $screenshotPath');
    await overlay(config, screenResources, screenshotPath);

    if (deviceType == DeviceType.android) {
      // add nav bar for each screenshot
      print('appending navigation bar to screenshot at $screenshotPath');
      await append(config, screenResources, screenshotPath);
    }

    // add frame if required
    if (config['frame']) {
      print(
          'placing $screenshotPath in frame from ${screen['resources']['frame']} frame');
      await frame(config, screen, screenshotPath);
    }
  }

  // move to final destination for upload to stores
  final srcDir = '${config['staging']}/test';
  final dstDir = fastlane.path(deviceType, locale, '', screen['destName']);
  print('moving screenshots to $dstDir');
//  print('srcDir=$srcDir, dstDir=$dstDir');
  utils.clearDirectory(dstDir);
  utils.moveDirectory(srcDir, dstDir);
//  switch (deviceType) {
//    case DeviceType.android:
//      final dstDir = path(deviceType, locale, '', screen['destName']);
//      print('srcDir=$srcDir, dstDir=$dstDir');
//      _clearDirectory(dstDir);
//      _moveDirectory(srcDir, dstDir);
//      break;
//    case DeviceType.ios:
//      final dstDir = path(deviceType, locale, '', screen['destName']);
//      print('srcDir=$srcDir, dstDir=$dstDir');
//      _clearDirectory(dstDir);
//      _moveDirectory(srcDir, dstDir);
//  }
}

///
/// Overlay status bar over screenshot
///
Future overlay(Map config, Map screenResources, String screenshotPath) async {
  final statusbarPath = '${config['staging']}/${screenResources['statusbar']}';
//  final screenshotStatusbarPath =
//      '${config['staging']}/test/' + FileUtils.basename(screenshotPath);
  final options = {
    'screenshotPath': screenshotPath,
    'statusbarPath': statusbarPath,
//    'screenshotStatusbarPath': screenshotStatusbarPath,
  };
  await im.imagemagick('overlay', options);
}

///
/// Append android status bar to screenshot
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
/// Frame a screenshot with image of device
/// Resulting image is scaled to fit dimensions required by stores
///
void frame(Map config, Map screen, String screenshotPath) async {
  final Map resources = screen['resources'];

  final framePath = config['staging'] + '/' + resources['frame'];
  final size = screen['size'];
  final resize = screen['resize'];
  final offset = screen['offset'];
//  final screenshotPath = '${config['staging']}/test/0.png';

  final options = {
    'framePath': framePath,
    'size': size,
    'resize': resize,
    'offset': offset,
    'screenshotPath': screenshotPath,
  };
//  print('options=$options');
  await im.imagemagick('frame', options);
}
