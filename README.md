
[![pub package](https://img.shields.io/pub/v/screenshots.svg)](https://pub.dartlang.org/packages/screenshots)

![alt text][fade]

[fade]: https://github.com/mmcc007/screenshots/raw/master/fade.gif "Screenshot with overlayed status bar and appended navigation bar placed in frame"  
Screenshot with overlayed status bar and appended navigation bar placed in frame  

For an example of screenshots generated with `screenshots` on a live app see:
<a href="https://play.google.com/store/apps/details?id=com.orbsoft.todo"><img src="https://play.google.com/intl/en_us/badges/images/generic/en_badge_web_generic.png" width="40%" title="GitErDone" alt="GitErDone"></a>  

For information on automating `screenshots` with a CI/CD tool see [fledge](https://github.com/mmcc007/fledge).

# Screenshots

`screenshots` is a standalone command line utility and package for capturing screenshots for Flutter. It will start the required android emulators and iOS simulators, run your screen 
capture tests on each emulator/simulator, process the images, and drop them off for Fastlane for delivery to both stores.

It is inspired by three products from Fastlane:  
1. [Snapshots](https://docs.fastlane.tools/getting-started/ios/screenshots/)  
   This is used to capture screenshots on iOS using iOS UI Tests.
1. [Screengrab](https://docs.fastlane.tools/actions/screengrab/)  
   This captures screenshots on android using android espresso tests.
1. [FrameIt](https://docs.fastlane.tools/actions/frameit/)  
   This is used to place captured iOS screenshots in a device frame.

`screenshots` combines key features of all three Fastlane products.  
1. Captures screenshots from any iOS simulator or android emulator and processes images.
2. Frames screenshots in an iOS or android device frame.
3. The same Flutter integration test can be used across all simulators/emulators.  
   No need to use iOS UI Tests or Espresso.
4. Integrates with Fastlane's [deliver](https://docs.fastlane.tools/actions/deliver/) 
and [supply](https://docs.fastlane.tools/actions/supply/) for upload to respective stores.

See related [article](https://medium.com/@nocnoc/automated-screenshots-for-flutter-f78be70cd5fd) for more information.

# Usage

````
$ screenshots
````
Or, if using a config file other than the default 'screenshots.yaml':
````
$ screenshots -c <path to config file>
````

# Writing tests for `screenshots`
Taking screenshots using this package is straightforward.

A special function is provided in
the `screenshots` package that is called by the test each time you want to take a screenshot. `screenshots` will
then process the images appropriately during a `screenshots` run.

To take screenshots in your tests:
1. Include the `screenshots` package in your pubspec.yaml's dev_dependencies section  
   ````yaml
     screenshots: ^0.1.2
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
            final Map config = Config().config;
       ````  
    3. Throughout the test make calls to capture screenshots  
       ````dart
           await screenshot(driver, config, 'myscreenshot1');
       ````
       Note: make sure your screenshot names are unique across all your tests.

Note: to turn off the debug banner on your screens, in you MaterialApp() widget pass:
````dart
      debugShowCheckedModeBanner: false,  
````

# Configuration
`screenshots` depends on a configuration file, `screenshots.yaml`:
````yaml
# Screen capture tests
tests:
  - test_driver/test1.dart
  - test_driver/test2.dart

# Interim location of screenshots from tests
staging: /tmp/screenshots

# A list of locales supported in the app
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
`screenshots` automatically starts the emulators and simulators corresponding to the devices
in the `screenshots.yaml`.  

`screenshots` expects that the emulators and simulators corresponding 
to the devices in the configuration file are installed in the test machine.

# Installation
To install `screenshots` on the command line:
````bash
$ pub global activate screenshots
````
To upgrade, simply re-issue the command
````bash
$ pub global activate screenshots
````
Note: the `screenshots` version should be the same for both the command line and package.  
1. If upgrading the command line version of `screenshots`, it is helpful to also upgrade the version of `screenshots` in your pubspec.yaml.    
2. If upgrading `screenshots` in your pubspec.yaml, you should also upgrade the command line version.    

## Dependencies
`screenshots` depends on ImageMagick.  

Since screenshots are generally required for both iOS and Android, testing should be done on a Mac
(unless you are only testing for android).

````bash
brew update && brew install imagemagick
````

# Integration with Fastlane
Since `screenshots` is intended to be used with Fastlane, after `screenshots` completes, 
the images can be found in:
````
android/fastlane/metadata/android/en-US/images
ios/fastlane/screenshots/en-US
````
Images are in a format suitable for upload via [deliver](https://docs.fastlane.tools/actions/deliver/) 
and [supply](https://docs.fastlane.tools/actions/supply/)

If you intend to use fastlane it is better to install fastlane files, in both `ios` and `android`
directories, prior to running `screenshots`.  See [fledge](https://github.com/mmcc007/fledge) for more info.

# Resources
A minimum number of screen sizes are supported to meet the requirements of both stores.
The supported screen sizes currently supported, with the corresponding devices, can be
 found in [screens.yaml](https://github.com/mmcc007/screenshots/blob/master/lib/resources/screens.yaml). 
 
 Only supported screens can be used in your config file.  
 
 Note: This file is part of the package and is shown for information purposes
 only. It does not need to be modified. You can find the latest version in [screens.yaml](https://github.com/mmcc007/screenshots/blob/master/lib/resources/screens.yaml)
````yaml
  ios:
    screen1:
        size: 1242x2208
        resize: 75%
        resources:
          statusbar: resources/ios/1242/statusbar_black.png
          frame: resources/ios/phones/iPhone_7_Plus_Silver.png
        offset: -0-0
        devices:
          - iPhone 7 Plus
    screen2:
        size: 2048x2732
        resize: 75%
        resources:
          frame: resources/ios/phones/iPad_Pro_Silver.png
        offset: -0-0
        devices:
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
        devices:
          - Nexus 5X
        destName: phone
````
# Current limitations
* More screens can be added as necessary (the minimum required by Apple and Google stores are already provided).
* Ipad screens currently have no status bar (waiting for artwork).
* Locales not supported (the default is whatever locale currently set in the emulator/simulator).

# Issues and Pull Requests
This is an initial release and more features can be added. [Issues](https://github.com/mmcc007/screenshots/issues) and [pull requests](https://github.com/mmcc007/screenshots/pulls) are welcome.