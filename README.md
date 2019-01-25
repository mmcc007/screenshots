
[![pub package](https://img.shields.io/pub/v/screenshots.svg)](https://pub.dartlang.org/packages/screenshots)

![alt text][fade]

[fade]: https://github.com/mmcc007/screenshots/raw/master/fade.gif "Screenshot with overlayed status bar and appended navigation bar placed in frame"  
<sup>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Screenshot with overlayed status bar and appended navigation bar placed in frame
</sup>


# Screenshots

`screenshots` is a standalone command line utility and package for capturing screenshots for Flutter. 

It is inspired by three products from Fastlane:  
1. [Snapshots](https://docs.fastlane.tools/getting-started/ios/screenshots/)  
   This is used to capture screenshots on iOS using iOS UI Tests.
1. [Screengrab](https://docs.fastlane.tools/actions/screengrab/)  
   This captures screenshots on android using android espresso tests.
1. [FrameIt](https://docs.fastlane.tools/actions/frameit/)  
   This is used to place captured iOS screenshots in a device frame.

`screenshots` combines key features of all three products.  
1. Captures screenshots from any iOS or android device.
2. Frames screenshots in a device frame.
3. The same Flutter integration test can be used across all devices.  
   No need to use iOS UI Tests or Espresso.
4. Integrates with Fastlane's [deliver](https://docs.fastlane.tools/actions/deliver/) 
and [supply](https://docs.fastlane.tools/actions/supply/) for upload to respective stores.

# Writing tests for `screenshots`
Tests have to capture screenshots to a configured location. A special function is provided in
the `screenshots` package that is called by the test to take the screenshot. `screenshots` will
then process the images appropriately.

Taking screenshots using this package is straightforward.

To take screenshots in your tests:
1. Include the `screenshots` package in your pubspec.yaml's dev_dependencies section  
   ````yaml
     screenshots: ^0.0.2
   ````
   ... or whatever the current version is.
2. In your tests
    1. Import the dependencies  
       ````dart
       import 'package:screenshots/config.dart';
       import 'package:screenshots/capture_screen.dart';
       ````
    2. Create the config map at start of test  
       ````dart
            final Map config = Config('config.yaml').config;
       ````  
    3. Throughout the test make calls to capture screenshots  
       ````dart
           await screenshot(driver, config, 'myscreenshot1');
       ````
       Make sure your screenshot names are unique across all your tests.

# Configuration
`screenshots` depends on a single configuration file that is inspired
by Fastlane's Snapshot.
````yaml
# Screen capture tests
tests:
  - test_driver/test1.dart
  - test_driver/test2.dart

# Interim location of screenshots from tests
staging: /tmp/screenshots

# A list of locales supported in app
locales:
  - en-US
#  - de-DE

# A list of devices to emulate
devices:
  ios:
#    - iPhone X
    - iPhone 7 Plus
    - iPad Pro (12.9-inch) (2nd generation)
#   "iPhone 6",
#   "iPhone 6 Plus",
#   "iPhone 5",
#   "iPhone 4s",
#   "iPad Retina",
#   "iPad Pro"
  android:
    - Nexus 5X

# Frame screenshots
frame: true
````

# Emulators and Simulators
`screenshots` expects that the emulators and simulators (or actual devices) corresponding 
to the devices in the configuration file are installed in the test machine.

# Installation
To install `screenshots` on the command line:
````bash
pub global activate screenshots
````

##Dependencies
`screenshots` depends on ImageMagick.  

Since screenshots are required for both iOS and Android, testing must be done on a MacOS. So
ImageMagick only needs to be installed on a MacOS.

````bash
brew update && brew install imagemagick
````

# Usage

The default config file is `config.yaml`
````
screenshots
````
If using a different config file
````
screenshots -c <path to config file>
````

# Integration with Fastlane
After `screenshots` completes the images can be found in
````
android/fastlane/metadata/android/en-US/images
ios/fastlane/screenshots/en-US
````
in a format suitable for upload via [deliver](https://docs.fastlane.tools/actions/deliver/) 
and [supply](https://docs.fastlane.tools/actions/supply/)

# Resources
A minimum number of screen sizes are supported to meet the requirements of both stores.
The supported screen sizes currently supported, with the corresponding devices, can be
 found in 'devices.yaml'
````yaml
  ios:
    screen1:
        size: 1242x2208
        resize: 75%
        resources:
          statusbar: resources/ios/1242/statusbar_black.png
          frame: resources/ios/phones/iPhone_7_Plus_Silver.png
        offset: -0-0
        phones:
          - iPhone 7 Plus
    screen2:
        size: 2048x2732
        resize: 75%
        resources:
          frame: resources/ios/phones/iPad_Pro_Silver.png
        offset: -0-0
        phones:
          - iPad Pro (12.9-inch) (2nd generation)
  android:
    screen1:
        size: 1080x1920
        resize: 80%
        resources:
          statusbar: resources/android/1080/statusbar.png
          navbar: resources/android/1080/navbar.png
          frame: resources/android/phones/Nexus_5X.png
        offset: -4-9
        phones:
          - Nexus 5X
        destName: phone
````
# Current limitations
* More screens can be added as necessary
* Ipad screens have no status bar
* locales not supported (the default is en-US)

# Issues and Pull Requests
This is an initial release and more features can be added. So issues and pull requests are welcome.