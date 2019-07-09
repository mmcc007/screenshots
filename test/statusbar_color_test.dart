import 'package:screenshots/src/image_magick.dart' as im;
import 'package:test/test.dart';

main() {
  test('select black or white statusbar', () {
    final imagePath = './test/resources/0.png';
    final cropSize = '1242x42+0+0';
    // if threshold exceeded select black
    if (im.thresholdExceeded(imagePath, cropSize, 0.76)) {
      print('use black statusbar');
    } else {
      print('use white statusbar');
    }
  });
}
