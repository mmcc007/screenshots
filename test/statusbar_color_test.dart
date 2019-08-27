import 'package:screenshots/src/context_runner.dart';
import 'package:screenshots/src/globals.dart';
import 'package:test/test.dart';
import 'package:screenshots/src/utils.dart' as utils;

main() async {
  test('threshold exceeded', () async {
    final imagePath = utils.toPlatformPath('./test/resources/0.png');
    final cropSize = '1242x42+0+0';
    bool isThresholdExceeded = await runInContext<bool>(() async {
      return im.thresholdExceeded(imagePath, cropSize, 0.5);
    });
    expect(isThresholdExceeded, isTrue);
    isThresholdExceeded = await runInContext<bool>(() async {
      return im.thresholdExceeded(imagePath, cropSize);
    });
    expect(isThresholdExceeded, isFalse);
  });
}
