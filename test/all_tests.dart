import 'package:screenshots/src/utils.dart';

import 'screenshots_test.dart' as screenshots_test;
import 'daemon_test.dart' as daemon_test;
import 'env_test.dart' as env_test;
import 'frame_test.dart' as frame_test;
import 'process_images_test.dart' as process_images_test;
import 'screenshots_yaml_test.dart' as screenshots_yaml_test;
import 'statusbar_color_test.dart' as statusbar_color_test;
import 'regression/issue_29.dart' as regression_issue_29_test;
import 'regression/regression_test.dart' as regression_regression_test;
import 'run_test.dart' as run_test;
import 'base/all_tests.dart' as base_all_tests;
import 'src/all_tests.dart' as src_all_tests;
import 'image_magick_test.dart' as image_magick_test;
import 'resources_test.dart' as resources_test;
import 'fastlane_test.dart' as fastlane_test;
import 'daemon_client_test.dart' as daemon_client_test;
import 'config_test.dart' as config_test;

void main() {
  isCI() ? print('running in CI') : print('not running in CI');

  config_test.main();
  daemon_client_test.main();
  src_all_tests.main();
  run_test.main();
  base_all_tests.main();
  image_magick_test.main();
  resources_test.main();
  fastlane_test.main();
  screenshots_test.main();
  daemon_test.main();
  env_test.main();
  frame_test.main();
  process_images_test.main();
  screenshots_yaml_test.main();
  statusbar_color_test.main();
  regression_issue_29_test.main();
  regression_regression_test.main();
}
