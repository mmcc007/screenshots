import 'dart:convert';
import 'package:yaml/yaml.dart';
import 'package:resource/resource.dart';

///
/// Parse devices file
///
class Devices {
  static const devicePath = 'resources/devices.yaml';
//  YamlNode docYaml;
//  Devices() {
////    docYaml = loadYaml(File(devicePath).readAsStringSync());
//    var resource = new Resource("package:screenshots/$devicePath");
//    resource.readAsString(encoding: utf8).then((devices) {
//      docYaml = loadYaml(devices);
//    });
//  }

  Future<YamlNode> init() async {
    var resource = Resource("package:screenshots/$devicePath");
    String devices = await resource.readAsString(encoding: utf8);
    return loadYaml(devices);
  }

  Map screen(YamlNode devices, String deviceName) {
    Map screenProps;

//    print(docYaml.value);
    devices.value.forEach((os, v) {
//      print('os=$os, v=$v');
      v.value.forEach((screenNum, _screenProps) {
//        print('screenNum=$screenNum, screenProps=$_screenProps');
        print('phones=${_screenProps['phones'][0]}');
        if (_screenProps['phones'].contains(deviceName)) {
          screenProps = _screenProps;
//          screenProps.remove('phones'); // unmodifiable
        }
//        v.value.forEach((k, v) {
//          print('k=$k, v=$v');
//        });
      });
    });
    return screenProps;
  }
}
