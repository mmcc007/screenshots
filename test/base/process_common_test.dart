import 'package:platform/platform.dart';
import 'package:screenshots/src/base/process_common.dart';
import 'package:test/test.dart';

main() {
  group('main', () {
    Platform fakePlatform;
    setUp(() {
      fakePlatform = FakePlatform.fromPlatform(const LocalPlatform())
        ..environment = {'PATH': '/Users/jenkins/Library/flutter/bin'};
    });

    test('check flutter', () {
      final flutterPath =
          getExecutablePath('flutter', '.', platform: fakePlatform);
      expect(flutterPath, isNotNull);
    });
  });
}
