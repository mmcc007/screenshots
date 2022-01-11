import '../../src/globals.dart';
import '../../src/resources.dart';

import 'android/1080/navbar.png.dart' as i13;
import 'android/1080/statusbar.png.dart' as i12;
import 'android/1440/navbar_black.png.dart' as i16;
import 'android/1440/statusbar.png.dart' as i15;
import 'android/1536/navigationbar.png.dart' as i19;
import 'android/1536/statusbar.png.dart' as i18;
import 'android/phones/Nexus 6P.png.dart' as i17;
import 'android/phones/Nexus_5X.png.dart' as i14;
import 'android/tablets/Nexus 9.png.dart' as i20;
import 'ios/1125/statusbar_black.png.dart' as i4;
import 'ios/1125/statusbar_white.png.dart' as i3;
import 'ios/1242/statusbar_black.png.dart' as i1;
import 'ios/2048/statusbar_white.png.dart' as i9;
import 'ios/6.5inch/statusbar_black.png.dart' as i7;
import 'ios/6.5inch/statusbar_white.png.dart' as i6;
import 'ios/phones/Apple iPhone X Silver.png.dart' as i5;
import 'ios/phones/Apple iPhone XS Max Silver.png.dart' as i8;
import 'ios/phones/iPad_Pro_Silver.png.dart' as i10;
import 'ios/phones/iPad_Pro_Space_Grey_3rd_Generation.png.dart' as i11;
import 'ios/phones/iPhone_7_Plus_Silver.png.dart' as i2;

const List<ScreenInfo> screens = [
  ScreenInfo(
    DeviceType.ios,
    '5.5inch',
    "1242x2208",
    "75%",
    "-0-0",
    null,
    [
      'iPhone 6 Plus',
      'iPhone 6S Plus',
      'iPhone 6s Plus',
      'iPhone 7 Plus',
      'iPhone 8 Plus',
    ],
    statusbar: i1.r,
    statusbarBlack: i1.r,
    statusbarWhite: i1.r,
    frame: i2.r,
  ),
  ScreenInfo(
    DeviceType.ios,
    '5.8inch',
    "1125x2436",
    "87%",
    "-0-0",
    null,
    [
      'iPhone X',
      'iPhone XS',
      'iPhone Xs',
    ],
    statusbar: i3.r,
    statusbarBlack: i4.r,
    statusbarWhite: i3.r,
    frame: i5.r,
  ),
  ScreenInfo(
    DeviceType.ios,
    '6.5inch',
    "1242x2688",
    "87%",
    "-0-2",
    null,
    [
      'iPhone XS Max',
      'iPhone Xs Max',
      'iPhone 11 Pro Max',
    ],
    statusbar: i6.r,
    statusbarBlack: i7.r,
    statusbarWhite: i6.r,
    frame: i8.r,
  ),
  ScreenInfo(
    DeviceType.ios,
    '12.9inch',
    "2048x2732",
    "86%",
    "-0-0",
    null,
    [
      'iPad Pro (12.9-inch) (1st generation)',
      'iPad Pro (12.9-inch) (2nd generation)',
    ],
    statusbar: i9.r,
    statusbarBlack: i9.r,
    statusbarWhite: i9.r,
    frame: i10.r,
  ),
  ScreenInfo(
    DeviceType.ios,
    '12.9inch_3rd_generation',
    "2048x2732",
    "91.25%",
    "-3+2",
    null,
    [
      'iPad Pro (12.9-inch) (3rd generation)',
    ],
    statusbar: i9.r,
    statusbarBlack: i9.r,
    statusbarWhite: i9.r,
    frame: i11.r,
  ),
  ScreenInfo(
    DeviceType.android,
    '5.2inch',
    "1080x1920",
    "80%",
    "-4-9",
    "phone",
    [
      'Nexus 5X',
    ],
    statusbar: i12.r,
    statusbarBlack: i12.r,
    statusbarWhite: i12.r,
    navbar: i13.r,
    frame: i14.r,
  ),
  ScreenInfo(
    DeviceType.android,
    '5.7inch',
    "1440x2560",
    "80%",
    "-3+8",
    "phone",
    [
      'Nexus 6P',
    ],
    statusbar: i15.r,
    statusbarBlack: i15.r,
    statusbarWhite: i15.r,
    navbar: i16.r,
    frame: i17.r,
  ),
  ScreenInfo(
    DeviceType.android,
    '8.9inch',
    "1536x2048",
    "80%",
    "+0+0",
    "tenInch",
    [
      'Nexus 9',
    ],
    statusbar: i18.r,
    statusbarBlack: i18.r,
    statusbarWhite: i18.r,
    navbar: i19.r,
    frame: i20.r,
  ),
  ScreenInfo(
    DeviceType.android,
    'default phone',
    null,
    null,
    null,
    "phone",
    [
      'default phone',
      'Nexus 6',
    ],
  ),
  ScreenInfo(
    DeviceType.android,
    'default sevenInch',
    null,
    null,
    null,
    "sevenInch",
    [
      'default seven inch',
    ],
  ),
  ScreenInfo(
    DeviceType.android,
    'default tenInch',
    null,
    null,
    null,
    "tenInch",
    [
      'default ten inch',
    ],
  ),
];
