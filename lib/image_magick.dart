import 'package:screenshots/utils.dart';

///
/// ImageMagick calls.
///
Future imagemagick(String command, Map options) async {
  List<String> cmdOptions;
  switch (command) {
    case 'resize':
      break;
    case 'overlay':
      cmdOptions = [
        options['screenshotPath'],
        options['statusbarPath'],
        '-composite',
//        options['screenshotStatusbarPath'],
        options['screenshotPath'],
      ];
//      print('cmdOptions=${cmdOptions.join(" ")}');
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
//      #convert -size $size xc:skyblue \
//  #          \( "$frameFile" -resize $resize \) -gravity center -composite \
//  #          \( final_screenshot.png -resize $resize \) -gravity center -geometry -4-9 -composite \
//  #          framed.png

      cmdOptions = [
        '-size',
        options['size'],
//        'xc:skyblue',
        'xc:none',
        '(',
        options['framePath'],
        '-resize',
        options['resize'],
        ')',
        '-gravity',
        'center',
        '-composite',
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
        options['screenshotPath']
      ];
      break;
    default:
      throw 'unknown command: $command';
  }
  cmd('convert', cmdOptions);
}
