import 'dart:io';

import 'package:yaml/yaml.dart';

///
/// Config info used to process screenshots for android and ios.
///
class Config {
  YamlNode docYaml;
  Config(String configPath) {
    docYaml = loadYaml(File(configPath).readAsStringSync());
  }

  /// Get configuration information for supported devices
  Map get config => docYaml.value;
}
