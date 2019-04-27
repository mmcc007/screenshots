import 'package:screenshots/image_magick.dart';
import 'package:screenshots/utils.dart';
import 'package:test/test.dart';

//const kThreshold = 0.75;
//const kThreshold = 0.76;

main() {
  test('select black or white statusbar', () {
    final imagePath = './test/resources/0.png';
    final cropSize = '1242x42+0+0';
//    print('pwd=${cmd('pwd', [])}');
    // if threshold exceeded select black
    if (thresholdExceeded(imagePath, cropSize, 0.76)) {
      print('use black statusbar');
    } else {
      print('use white statusbar');
    }
  });
}
