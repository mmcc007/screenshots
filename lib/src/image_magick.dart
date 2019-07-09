import 'dart:async';

import 'utils.dart';

const kThreshold = 0.76;
//const kThreshold = 0.5;

///
/// ImageMagick calls.
///
Future imagemagick(String command, Map options) async {
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
  cmd('convert', cmdOptions);
}

/// Checks if brightness of section of image exceeds a threshold
bool thresholdExceeded(String imagePath, String crop,
    [double threshold = kThreshold]) {
  //convert logo.png -crop $crop_size$offset +repage -colorspace gray -format "%[fx:(mean>$threshold)?1:0]" info:
  final result = cmd(
      'convert',
      [
        imagePath,
        '-crop',
        crop,
        '+repage',
        '-colorspace',
        'gray',
        '-format',
        '\'%[fx:(mean>$threshold)?1:0]\'',
        'info:'
      ],
      '.',
      true);
//  print('result=$result');
  return result.contains('1'); // looks like there is some junk in string
}
