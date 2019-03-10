
[![pub package](https://img.shields.io/pub/v/screenshots.svg)](https://pub.dartlang.org/packages/screenshots) 
[![Build Status](https://travis-ci.com/mmcc007/screenshots.svg?branch=master)](https://travis-ci.com/mmcc007/screenshots)

![alt text][demo]

[demo]: https://i.imgur.com/gkIEQ5y.gif "Screenshot with overlayed 
status bar and appended navigation bar placed in frame"  
A screenshot image with overlaid status bar and appended navigation bar placed in a device frame.  

For an example of images generated with _Screenshots_ on a live app in both stores see:  
[![GitErDone](https://play.google.com/intl/en_us/badges/images/badge_new.png)](https://play.google.com/store/apps/details?id=com.orbsoft.todo)
[![GitErDone](https://linkmaker.itunes.apple.com/en-us/badge-lrg.svg?releaseDate=2019-02-15&kind=iossoftware)](https://itunes.apple.com/us/app/giterdone/id1450240301)


See a demo of _Screenshots_ in action:
[![Screenshots demo](https://i.imgur.com/V9VFSYb.png)](https://vimeo.com/317112577 "Screenshots demo - Click to Watch!")

For introduction to _Screenshots_ see https://medium.com/@nocnoc/automated-screenshots-for-flutter-f78be70cd5fd.

# _Screenshots_

_Screenshots_ is a standalone command line utility and package for capturing screenshot images for Flutter.   

_Screenshots_ will start the required android emulators and iOS simulators, run your screen capture tests on each emulator/simulator, process the images, and drop them off to Fastlane for delivery to both stores.

It is inspired by three tools from Fastlane:  
1. [Snapshots](https://docs.fastlane.tools/getting-started/ios/screenshots/)  
This is used to capture screenshots on iOS using iOS UI Tests.
1. [Screengrab](https://docs.fastlane.tools/actions/screengrab/)  
This captures screenshots on android using android espresso tests.
1. [FrameIt](https://docs.fastlane.tools/actions/frameit/)  
This is used to place captured iOS screenshots in a device frame.

Since all three of these Fastlane tools do not work with Flutter, _Screenshots_ combines key features of all three Fastlane tools into one tool. Plus, it is much easier to use! 

# Features
_Screenshots_ main features includes:  
1. One test for both platforms  
Write one test for both iOS and Android.  
(No need to write separate iOS UI Tests or Espresso tests.)
1. One run for both platforms  
_Screenshots_ runs your tests on both iOS and Android in one run.  
(as opposed to making separate Snapshots and Screengrab runs)
1. One run for multiple tests  
_Screenshots_ will run all the tests listed in config file.
1. One run for multiple locales  
If your app supports multiple locales, _Screenshots_ will optionally set the locales listed in the config file before running each test.
1. One run for frames  
Optionally places images in device frames in same run.  
(as opposed to making separate FrameIt runs... which supports iOS only)
1. One run for clean status bars  
Every image that _Screenshots_ generates has a clean status bar.  
(no need to run a separate stage to clean-up status bars)
1. Support for macOS, Linux and Windows  
_Screenshots_ can be setup to run on macOS in the cloud. So development can continue on Linux and/or Windows.  
(For demo of _Screenshots_ running the internationalized [example](example) app on macOS in cloud see [below](#sample-run-on-travis))
1. Works with Fastlane  
_Screenshots_ drops-off images where Fastlane expects to find them. Fastlane's [deliver](https://docs.fastlane.tools/actions/deliver/) and [supply](https://docs.fastlane.tools/actions/supply/) can then be used to upload to respective stores.  
(For live demo of uploading screenshot images to both store consoles using Fastlane see demo of Fledge at https://github.com/mmcc007/fledge#demo)

# Installation
````bash
$ pub global activate screenshots
````

# Usage

````
$ screenshots
````
Or, if using a config file other than the default 'screenshots.yaml':
````
$ screenshots -c <path to config file>
````

# Modifying your tests for _Screenshots_
A special function is provided in the _Screenshots_ package that is called by the test each time you want to capture a screenshot. 
_Screenshots_ will then process the images appropriately during a _Screenshots_ run.

To capture screenshots in your tests:
1. Include the _Screenshots_ package in your pubspec.yaml's dev_dependencies section  
   ````yaml
     screenshots: ^<current version>
   ````
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
_Screenshots_ uses a configuration file to configure a run.  
 The default config filename is `screenshots.yaml`:
````yaml
# A list of screen capture tests
tests:
  - test_driver/main1.dart
  - test_driver/main2.dart

# Note: flutter driver expects a pair of files for testing
# For example:
#   main1.dart is the test app (that calls your app)
#   main1_test.dart is the matching test that flutter driver 
#   expects to find.

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
    - iPad Pro (12.9-inch) (2nd generation)
  android:
    - Nexus 6P

# Frame screenshots
frame: true
````
Note: emulators and simulators corresponding to the devices in your config file must be installed on your test machine.

## Dependencies
_Screenshots_ depends on ImageMagick.  

Since screenshots are required by both Apple and Google stores, testing should be done on a Mac (unless you are only testing for android).

````bash
brew update && brew install imagemagick
````

# Integration with Fastlane
Since _Screenshots_ is intended to be used with Fastlane, after _Screenshots_ completes, the images can be found in your project at:
````
android/fastlane/metadata/android
ios/fastlane/screenshots
````
Images are in a format suitable for upload via [deliver](https://docs.fastlane.tools/actions/deliver/) 
and [supply](https://docs.fastlane.tools/actions/supply/).

Tip: The easiest way to use _Screenshots_ with Fastlane is to call _Screenshots_ before calling Fastlane. Calling Fastlane (for either iOS or Android) will then find the images in the appropriate place.  
(For a live demo of using Fastlane to upload screenshot images to both store consoles for Flutter, see demo of Fledge at https://github.com/mmcc007/fledge#demo)

## Changing devices

To change the devices to run your tests on, just change the list of devices in screenshots.yaml.

Make sure the devices you select have supported screens and corresponding emulators/simulators.

Note: _In practice, multiple devices share the same screen size.
Devices are therefore organized by supported screen size in a file called `screens.yaml`._

For each selected device:
1. Confirm device is present in [screens.yaml](https://github.com/mmcc007/screenshots/blob/master/lib/resources/screens.yaml).  
2. Add device to the list of devices in screenshots.yaml.  
3. Install an emulator or simulator for device.   
 
If changing devices seems tricky at first, don't worry. _Screenshots_ will validate your configuration before running.

Note: If you want to use a device that is not included in screens.yaml, create an [issue](https://github.com/mmcc007/screenshots/issues). Include the name of the device and preferably the size of the screen in pixels (for example, Nexus 5X:1080x1920).

# Upgrading
To upgrade, simply re-issue the install command
````bash
$ pub global activate screenshots
````
Note: the _Screenshots_ version should be the same for both the command line and package:
1. If upgrading the command line version of _Screenshots_, it is helpful to also upgrade
 the version of _Screenshots_ in your pubspec.yaml.    
2. If upgrading _Screenshots_ in your pubspec.yaml, you should also upgrade the command line version.    

# Sample run on Travis
To view _Screenshots_ running with the internationalized [example](example) app on macOS in the cloud see:  
https://travis-ci.com/mmcc007/screenshots

To view the images generated by _Screenshots_ during run on travis see:  
https://github.com/mmcc007/screenshots/releases/

Note: running _Screenshots_ on macOS in the cloud is useful when developing on Linux and/or Windows. Running _Screenshots_ in the cloud is also useful for automating your screenshots generation in a CI/CD environment. 

# Issues and Pull Requests
[Issues](https://github.com/mmcc007/screenshots/issues) and 
[pull requests](https://github.com/mmcc007/screenshots/pulls) are welcome.

Your feedback is welcome and is used to guide where development effort is focused. So feel free to create as many issues and pull requests as you want. You should expect a timely and considered response.