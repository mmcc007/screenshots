import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:screenshots/src/utils.dart';
import 'package:tool_base/tool_base.dart';

import 'context_runner.dart';

final ImageMagick _kImageMagick = ImageMagick();

/// Currently active implementation of ImageMagick.
///
/// Override this in tests with a fake/mocked daemon client.
ImageMagick get im => context.get<ImageMagick>() ?? _kImageMagick;

class ImageMagick {
  static const _kThreshold = 0.76;
  static const kDiffSuffix = '-diff';

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
    _imageMagickCmd('convert', cmdOptions);
  }

  /// Checks if brightness of sample of image exceeds a threshold.
  /// Section is specified by [cropSizeOffset] which is of the form
  /// cropSizeOffset, eg, '1242x42+0+0'.
  bool isThresholdExceeded(String imagePath, String cropSizeOffset,
      [double threshold = _kThreshold]) {
    //convert logo.png -crop $crop_size$offset +repage -colorspace gray -format "%[fx:(mean>$threshold)?1:0]" info:
    final result = cmd(_getPlatformCmd('convert', <String>[
      imagePath,
      '-crop',
      cropSizeOffset,
      '+repage',
      '-colorspace',
      'gray',
      '-format',
      '""%[fx:(mean>$threshold)?1:0]""',
      'info:'
    ])).replaceAll('"', ''); // remove quotes ""0""
    return result == '1';
  }

  bool compare(String comparisonImage, String recordedImage) {
    final diffImage = getDiffImagePath(comparisonImage);

    int returnCode = _imageMagickCmd('compare',
        <String>['-metric', 'mae', recordedImage, comparisonImage, diffImage]);

    if (returnCode == 0) {
      // delete no-diff diff image created by image magick
      fs.file(diffImage).deleteSync();
    }
    return returnCode == 0;
  }

  /// Append diff suffix [kDiffSuffix] to [imagePath].
  String getDiffImagePath(String imagePath) {
    final diffName = p.dirname(imagePath) +
        '/' +
        p.basenameWithoutExtension(imagePath) +
        kDiffSuffix +
        p.extension(imagePath);
    return diffName;
  }

  void deleteDiffs(String dirPath) {
    fs
        .directory(dirPath)
        .listSync()
        .where((fileSysEntity) =>
            p.basename(fileSysEntity.path).contains(kDiffSuffix))
        .forEach((diffImage) => fs.file(diffImage.path).deleteSync());
  }

  /// Different command for windows (based on recommended installed version!)
  List<String> _getPlatformCmd(String imCmd, List imCmdArgs) {
    // windows uses ImageMagick v7 or later which by default does not
    // have the legacy commands.
    if (platform.isWindows) {
      return [
        ...['magick'],
        ...[imCmd],
        ...imCmdArgs
      ];
    } else {
      return [
        ...[imCmd],
        ...imCmdArgs
      ];
    }
  }

  /// ImageMagick command
  int _imageMagickCmd(String imCmd, List imCmdArgs) {
    return runCmd(_getPlatformCmd(imCmd, imCmdArgs));
  }
}

/// Check Image Magick is installed.
Future<bool> isImageMagicInstalled() async {
  try {
    return await runInContext<bool>(() {
      var cmd =
          platform.isWindows ? ['magick', '-version'] : ['convert', '-version'];

      return runCmd(cmd) == 0;
    });
  } catch (e) {
    return false;
  }
}
