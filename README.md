
[![pub package](https://img.shields.io/pub/v/screenshots.svg)](https://pub.dartlang.org/packages/screenshots) 
[![Build Status](https://travis-ci.com/mmcc007/screenshots.svg?branch=master)](https://travis-ci.com/mmcc007/screenshots)

![alt text][fade]

[fade]: https://github.com/mmcc007/screenshots/raw/master/fade.gif "Screenshot with overlayed 
status bar and appended navigation bar placed in frame"  
Screenshot with overlaid status bar and appended navigation bar placed in a device frame.  

For an example of images generated with `screenshots` on a live app see:  
<a href="https://play.google.com/store/apps/details?id=com.orbsoft.todo"><img src="https://play.google.com/intl/en_us/badges/images/generic/en_badge_web_generic.png" width="40%" title="GitErDone" alt="GitErDone"></a>

For introduction to `screenshots` see [article](https://medium.com/@nocnoc/automated-screenshots-for-flutter-f78be70cd5fd).

For information on automating `screenshots` with a CI/CD tool see 
[fledge](https://github.com/mmcc007/fledge).

# Screenshots

`screenshots` is a standalone command line utility and package for capturing screenshots for 
Flutter. It will start the required android emulators and iOS simulators, run your screen 
capture tests on each emulator/simulator for each locale your app supports, process the images, and drop them off for Fastlane 
for delivery to both stores.

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

# Usage

````
$ screenshots
````
Or, if using a config file other than the default 'screenshots.yaml':
````
$ screenshots -c <path to config file>
````

# Modifying tests for `screenshots`
Capturing screenshots using this package is straightforward.

A special function is provided in
the `screenshots` package that is called by the test each time you want to capture a screenshot. 
`screenshots` will
then process the images appropriately during a `screenshots` run.

To capture screenshots in your tests:
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

Note: to turn off the debug banner on your screens, in your integration test's main(), call:
````dart
  WidgetsApp.debugAllowBannerOverride = false; // remove debug banner for screenshots
````

# Configuration
To run `screenshots` you need to setup a configuration file, `screenshots.yaml`:
````yaml
# Screen capture tests
tests:
  - test_driver/test1.dart
  - test_driver/test2.dart

# Interim location of screenshots from tests
staging: /tmp/screenshots

# A list of locales supported by the app
locales:
  - de-DE
  - en-US

# A list of devices to emulate
devices:
  ios:
    - iPhone X
#    - iPhone 7 Plus
    - iPad Pro (12.9-inch) (2nd generation)
#   "iPhone 6",
#   "iPhone 6 Plus",
#   "iPhone 5",
#   "iPhone 4s",
#   "iPad Retina",
#   "iPad Pro"
  android:
    - Nexus 6P
#    - Nexus 5X

# Frame screenshots
frame: true
````
Note: emulators and simulators corresponding to the devices in your config file must be installed
on your test machine.

## Changing configuration
If you want to change the list of devices to run, to get different screenshots, make sure the devices
you select have supported screens and corresponding emulators/simulators.

Within each class of ios and android device, multiple devices share the same screen size.
Devices are therefore organized by supported screens in a file called `screens.yaml`.

To modify the config file with the devices you select to emulate/simulate:
1. Locate each selected device in latest 
[screens.yaml](https://github.com/mmcc007/screenshots/blob/master/lib/resources/screens.yaml).  
Use the latest `screens.yaml`, not the sample below.
2. Modify the list of devices in `screenshots.yaml` to your selected devices.  
Confirm that each selected device name matches a name used in `screens.yaml` 
3. Install an emulator/simulator for each selected device.  
Confirm that each selected device used in `screenshots.yaml` has an emulator/simulator
with a matching name.  
 
 
`screenshots` will validate the config file before running.

Sample screens.yaml:
````yaml
ios:
  5.5inch:
    size: 1242x2208
    resize: 75%
    resources:
      statusbar: resources/ios/1242/statusbar_black.png
      frame: resources/ios/phones/iPhone_7_Plus_Silver.png
    offset: -0-0
    devices:
      - iPhone 7 Plus
  12.9inch:
    size: 2048x2732
    resize: 75%
    resources:
      frame: resources/ios/phones/iPad_Pro_Silver.png
    offset: -0-0
    devices:
      - iPad Pro (12.9-inch) (2nd generation)
android:
  5.2inch:
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
If you want to use a device that is not included in screens.yaml
, please create an [issue](https://github.com/mmcc007/screenshots/issues). Include
the name of the device and preferably the size of the screen in pixels 
(for example, Nexus 5X:1080x1920).

# Installation
To install `screenshots` on the command line:
````bash
$ pub global activate screenshots
````
To upgrade, simply re-issue the command
````bash
$ pub global activate screenshots
````
Note: the `screenshots` version should be the same for both the command line and package:
1. If upgrading the command line version of `screenshots`, it is helpful to also upgrade
 the version of `screenshots` in your pubspec.yaml.    
2. If upgrading `screenshots` in your pubspec.yaml, you should also upgrade the command line version.    

## Dependencies
`screenshots` depends on ImageMagick.  

Since screenshots are required by both Apple and Google stores, testing should be done on a Mac
(unless you are only testing for android).

````bash
brew update && brew install imagemagick
````

# Integration with Fastlane
Since `screenshots` is intended to be used with Fastlane, after `screenshots` completes, 
the images can be found in:
````
android/fastlane/metadata/android
ios/fastlane/screenshots
````
Images are in a format suitable for upload via [deliver](https://docs.fastlane.tools/actions/deliver/) 
and [supply](https://docs.fastlane.tools/actions/supply/).

If you intend to use fastlane it is better to install fastlane files, in both `ios` and `android`
directories, prior to running `screenshots`. 
(See [fledge](https://github.com/mmcc007/fledge) for more info.)

# Issues and Pull Requests
[Issues](https://github.com/mmcc007/screenshots/issues) and 
[pull requests](https://github.com/mmcc007/screenshots/pulls) are welcome.