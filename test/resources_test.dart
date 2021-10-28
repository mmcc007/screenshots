import 'package:mockito/mockito.dart';
import 'package:process/process.dart';
import 'package:screenshots/src/resources.dart';
import 'package:screenshots/src/screens.dart';
import 'package:test/test.dart';
import 'package:tool_base/tool_base.dart';

import 'src/context.dart';
import 'src/mocks.dart';

void main() {
  group('resources', () {
    final tmpDir = '/tmp/screenshots_test';

    group('in context', () {
      var mockProcessManager = MockProcessManager();

      setUp(() {
        mockProcessManager = MockProcessManager();
        when(mockProcessManager.runSync(
          any,
          environment: anyNamed('environment'),
          workingDirectory: anyNamed('workingDirectory'),
          runInShell: anyNamed('runInShell'),
        )).thenAnswer(
            (Invocation invocation) => ProcessResult(0, 0, null, null));
      });

      testUsingContext('unpack scripts', () async {
        final result = await unpackScripts(tmpDir);
        expect(result, isNull);
      }, overrides: {ProcessManager: () => mockProcessManager});
    });

    group('no context', () {
      test('unpack screen resource images', () async {
        final screens = Screens();
        final screen = screens.getScreen('iPhone 7 Plus')!;
        await unpackImages(screen, tmpDir);
      });
    });
  });
}
