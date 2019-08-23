import 'package:screenshots/src/globals.dart';
import 'package:test/test.dart';
import 'package:screenshots/src/utils.dart' as utils;

main() {
  test('threshold exceeded', () {
    final imagePath = utils.toPlatformPath('./test/resources/0.png');
    final cropSize = '1242x42+0+0';
    expect(im.thresholdExceeded(imagePath, cropSize, 0.5), isTrue);
    expect(im.thresholdExceeded(imagePath, cropSize), isFalse);
  });
}
