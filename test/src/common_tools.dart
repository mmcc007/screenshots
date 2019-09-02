import 'package:test/test.dart';
//import 'package:test_api/test_api.dart' hide TypeMatcher, isInstanceOf;
import 'package:test_api/test_api.dart' as test_package show TypeMatcher;
import 'package:tool_base/tool_base.dart';
//export 'package:test_api/test_api.dart'
//    hide TypeMatcher, isInstanceOf; // Defines a 'package:test' shim.

/// taken from flutter tools

/// A matcher that compares the type of the actual value to the type argument T.
// TODO(ianh): Remove this once https://github.com/dart-lang/matcher/issues/98 is fixed
Matcher isInstanceOf<T>() => test_package.TypeMatcher<T>();

void tryToDelete(Directory directory) {
  // This should not be necessary, but it turns out that
  // on Windows it's common for deletions to fail due to
  // bogus (we think) "access denied" errors.
  try {
    directory.deleteSync(recursive: true);
  } on FileSystemException catch (error) {
    print('Failed to delete ${directory.path}: $error');
  }
}

/// Matcher for functions that throw [ToolExit].
Matcher throwsToolExit({int exitCode, Pattern message}) {
  Matcher matcher = isToolExit;
  if (exitCode != null)
    matcher = allOf(matcher, (ToolExit e) => e.exitCode == exitCode);
  if (message != null)
    matcher = allOf(matcher, (ToolExit e) => e.message.contains(message));
  return throwsA(matcher);
}

/// Matcher for [ToolExit]s.
final Matcher isToolExit = isInstanceOf<ToolExit>();
