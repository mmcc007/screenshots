import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'base/platform.dart';
import 'base/process.dart';

class ImageMagick {
  static const _kThreshold = 0.76;
  final diffSuffix = '-diff';
//const kThreshold = 0.5;

  // singleton
  static final ImageMagick _imageMagick = ImageMagick._internal();
  factory ImageMagick() {
    return _imageMagick;
  }
  ImageMagick._internal();

  ///
  /// ImageMagick calls.
  ///
  Future convert(String command, Map options) async {
    List<String> cmdOptions;
    switch (command) {
      case 'overlay':
        cmdOptions = [
          options['screenshotPath'],
          options['statusbarPath'],
          '-gravity',
          'north',
          '-composite',
          options['screenshotPath'],
        ];
        break;
      case 'append':
        // convert -append screenshot_statusbar.png navbar.png final_screenshot.png
        cmdOptions = [
          '-append',
          options['screenshotPath'],
          options['screenshotNavbarPath'],
          options['screenshotPath'],
        ];
        break;
      case 'frame':
//  convert -size $size xc:skyblue \
//   \( "$frameFile" -resize $resize \) -gravity center -composite \
//   \( final_screenshot.png -resize $resize \) -gravity center -geometry -4-9 -composite \
//   framed.png

        cmdOptions = [
          '-size',
          options['size'],
          options['backgroundColor'],
          '(',
          options['screenshotPath'],
          '-resize',
          options['resize'],
          ')',
          '-gravity',
          'center',
          '-geometry',
          options['offset'],
          '-composite',
          '(',
          options['framePath'],
          '-resize',
          options['resize'],
          ')',
          '-gravity',
          'center',
          '-composite',
          options['screenshotPath']
        ];
        break;
      default:
        throw 'unknown command: $command';
    }
    _cmd('convert', cmdOptions);
  }

  /// Checks if brightness of section of image exceeds a threshold
  bool thresholdExceeded(String imagePath, String crop,
      [double threshold = _kThreshold]) {
    //convert logo.png -crop $crop_size$offset +repage -colorspace gray -format "%[fx:(mean>$threshold)?1:0]" info:
    final result = _cmd('convert', <String>[
      imagePath,
      '-crop',
      crop,
      '+repage',
      '-colorspace',
      'gray',
      '-format',
      '""%[fx:(mean>$threshold)?1:0]""',
      'info:'
    ]).replaceAll('"', '');
    return result == '1';
  }

  bool compare(String comparisonImage, String recordedImage) {
    final diffImage = getDiffName(comparisonImage);
    try {
      _cmd('compare', <String>[
        '-metric',
        'mae',
        recordedImage,
        comparisonImage,
        diffImage
      ]);
    } catch (e) {
      return false;
    }
    // delete no-diff diff
    File(diffImage).deleteSync();
    return true;
  }

  String getDiffName(String comparisonImage) {
    final diffName = p.dirname(comparisonImage) +
        '/' +
        p.basenameWithoutExtension(comparisonImage) +
        diffSuffix +
        p.extension(comparisonImage);
    return diffName;
  }

  void deleteDiffs(String dirPath) {
    Directory(dirPath)
        .listSync()
        .where((fileSysEntity) =>
            p.basename(fileSysEntity.path).contains(diffSuffix))
        .forEach((diffImage) => File(diffImage.path).deleteSync());
  }

  /// ImageMagick command
  String _cmd(String imCmd, List imCmdArgs) {
    // windows uses ImageMagick v7 or later
    if (platform.isWindows) {
      return cmd([
        ...['magick'],
        ...[imCmd],
        ...imCmdArgs
      ]);
    } else {
      return cmd([
        ...[imCmd],
        ...imCmdArgs
      ]);
    }
  }
}
