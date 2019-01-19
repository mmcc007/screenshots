import 'package:screenshots/config.dart';
import 'package:screenshots/devices.dart';
import 'package:screenshots/image_magick.dart';
import 'package:screenshots/resources.dart';
import 'package:screenshots/utils.dart';
import 'package:test/test.dart';

void main() {
  test('screen info for device', () async {
    final expected = {
      'destName': 'phone',
      'frame': 'resource/android/phones/Nexus 5X.png',
      'phones': ['Nexus 5X', 'Nexus ????'],
      'size': '1080x1920',
      'resize': '80%',
      'statusbar': 'resources/android/1080/statusbar.png',
      'navbar': 'resources/android/1080/navbar.png',
      'offset': '-4-9'
    };
    final Devices devices = Devices();
    final devicesInfo = await Devices().init();
    Map screen = devices.screen(devicesInfo, 'Nexus 5X');
    expect(screen, expected);
  });

  test('config info for app', () {
    final expected = {
      'tests': ['test_driver/main.dart'],
      'locales': ['en-US'],
      'frame': true,
      'devices': {
        'android': ['Nexus 5X'],
        'ios': ['iPhone 7 Plus']
      },
      'staging': '/tmp/screenshots'
    };

    final Config config = Config('test/test_config.yaml');
    Map appConfig = config.config;
    expect(appConfig, expected);
  });

  test('overlay status bar', () async {
    final Devices devices = Devices();
    final devicesInfo = await devices.init();
    Map screen = devices.screen(devicesInfo, 'Nexus 5X');
    final Config config = Config('test/test_config.yaml');
    Map appConfig = config.config;

//    final screenshotPath = '/tmp/screenshots/test/0.png';
//    final statusbarResourcePath = 'resources/android/1080/statusbar.png';
//    final statusbarPath = '/tmp/statusbar.png';
//    final screenshotStatusbarPath = '/tmp/screenshots/test/0.png';

//    final statusbarResourcePath = screen['statusbar'];

    final Map resources = screen['resources'];

    final statusbarPath = '${appConfig['staging']}/${resources['statusbar']}';
    final screenshotPath = '${appConfig['staging']}/test/0.png';
    final screenshotStatusbarPath = '${appConfig['staging']}/test/0.png';

    final options = {
      'screenshotPath': screenshotPath,
//      'statusbarResourcePath': statusbarResourcePath,
      'statusbarPath': statusbarPath,
      'screenshotStatusbarPath': screenshotStatusbarPath,
    };
    print('options=$options');
    await imagemagick('overlay', options);
  });

  test('unpack screen resource images', () async {
    final Devices devices = Devices();
    final devicesInfo = await devices.init();
//    Map screen = devices.screen(devicesInfo, 'Nexus 5X');
    Map screen = devices.screen(devicesInfo, 'iPhone 7 Plus');
    final Config config = Config('test/test_config.yaml');
    Map appConfig = config.config;

    final staging = appConfig['staging'];

    final Map screenResources = screen['resources'];
//    print('resources=$resources');
//    List screenResources = [];
//    resources.forEach((k, resource) {
//      screenResources.add(resource);
//    });
    print('screenResources=$screenResources');

    await unpackImages(screenResources, staging);
  });

  test('append nav bar', () async {
    final Devices devices = Devices();
    final devicesInfo = await devices.init();
    Map screen = devices.screen(devicesInfo, 'Nexus 5X');
    final Config config = Config('test/test_config.yaml');
    Map appConfig = config.config;

    final Map resources = screen['resources'];

    final screenshotNavbarPath =
        '${appConfig['staging']}/${resources['navbar']}';
    final screenshotPath = '${appConfig['staging']}/test/0.png';

    final options = {
      'screenshotPath': screenshotPath,
      'screenshotNavbarPath': screenshotNavbarPath,
    };
    print('options=$options');
    await imagemagick('append', options);
  });

  test('frame screenshot', () async {
    final Devices devices = Devices();
    final devicesInfo = await devices.init();
    Map screen = devices.screen(devicesInfo, 'Nexus 5X');
    final Config config = Config('test/test_config.yaml');
    Map appConfig = config.config;

    final Map resources = screen['resources'];

    final framePath = appConfig['staging'] + '/' + resources['frame'];
    final size = screen['size'];
    final resize = screen['resize'];
    final offset = screen['offset'];
    final screenshotPath = '${appConfig['staging']}/test/0.png';

    final options = {
      'framePath': framePath,
      'size': size,
      'resize': resize,
      'offset': offset,
      'screenshotPath': screenshotPath,
    };
    print('options=$options');
    await imagemagick('frame', options);
  });

  test('parse xcrun simctl list', () {
//     String devices=cmd('xcrun', ['simctl', 'list'], '.', true);
////     print ('devices=$devices');
//     RegExp regExp = new RegExp(r'^    (.*) \((.*-.*-.*-.*)\) \((.*)\)$',
//         caseSensitive: false,
//         multiLine: true);
//    Iterable<Match> matches = regExp.allMatches(devices);
////    matches.forEach((match){
////      print('match=$match');
////    });
//    Map<String, Map<String, String>> simulators={};
//        for (Match m in matches) {
//           String match = m.group(0);
//           print(match);
//           print(m.group(1));
//           print(m.group(2));
//           print(m.group(3));
//           // load into map
//          Map<String, String> simulatorInfo={};
//          simulatorInfo['ID']= m.group(2);
//          simulatorInfo['status']=m.group(3);
//          simulators[m.group(1)]=simulatorInfo;
//         }
    Map _simulators = simulators();

    print('iPhone 7 Plus info: ' + _simulators['iPhone 7 Plus'].toString());

//     print('first match:' + regExp.firstMatch(devices).toString());
  });

  test('read resource and write to path', () async {
//    print(await sampleTxt());
//    print(await sampleImage());
////    print(await image('resources/sample.png'));
//    writeImage(await sampleImage(), '/tmp/sample.png');
    final resources = [
      'resources/android/1080/statusbar.png',
      'resources/android/1080/navbar.png',
      'resources/android/phones/Nexus_5X.png'
    ];
    final dest = '/tmp';
    for (String resource in resources)
      writeImage(await readImage(resource), '$dest/$resource');
  });

  test('simple unpack', () {
    final resources = {
      'A': 'resources/android/1080/statusbar.png',
      'B': 'resources/android/1080/navbar.png',
      'C': 'resources/android/phones/Nexus_5X.png'
    };
    final dest = '/tmp';
    unpackImages(resources, dest);
  });

  test('unpack script', ()async{
    await unpackScript('/tmp');
  }
  );
}
