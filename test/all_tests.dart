import 'screenshots_test.dart' as screenshots_test;
import 'daemon_test.dart' as daemon_test;
import 'frame_test.dart' as frame_test;
import 'image_processor_test.dart' as image_processor_test;
import 'screenshots_yaml_test.dart' as screenshots_yaml_test;
import 'regression/issue_29.dart' as regression_issue_29_test;
import 'regression/regression_test.dart' as regression_regression_test;
import 'run_test.dart' as run_test;
import 'src/all_tests.dart' as src_all_tests;
import 'image_magick_test.dart' as image_magick_test;
import 'resources_test.dart' as resources_test;
import 'fastlane_test.dart' as fastlane_test;
import 'daemon_client_test.dart' as daemon_client_test;
import 'config_test.dart' as config_test;
import 'screens_test.dart' as screens_test;
import 'validate_test.dart' as validate_test;
import 'utils_test.dart' as utils_test;
import 'base/all_tests.dart' as base_all_tests;

void main() {

  base_all_tests.main();
  config_test.main();
  daemon_client_test.main();
  fastlane_test.main();
  image_magick_test.main();
  image_processor_test.main();
  resources_test.main();
  // run_test.main();
  screens_test.main();
  utils_test.main();
  validate_test.main();

  screenshots_test.main();
  daemon_test.main();
  frame_test.main();
  screenshots_yaml_test.main();

  src_all_tests.main();
  regression_issue_29_test.main();
  regression_regression_test.main();
}
