## 2.0.0
- Added support for running on linux and windows #97 #96 #106
- Removed dependency on Yaml objects #98 #100
- Added support for driver params in config of test #101
- Added support for runtime/test contexts (from flutter tools) #104
- Added logger, platform and filesystem from flutter tools to context #105
- Added support for unknown devices (without framing) #102 #110
- Created utility to test framing when adding new screens #111
- Refactored Config to remove access to raw map #114  
    - Breaking change in calling screenshots in tests!!
- Refactored daemon client to remove access to raw map #115
- Added getters for adb and emulator paths #116
Included adding more components from flutter tools (AndroidSdk, Config, OperatingSystemUtils, etc...).
- Added verbose mode #109 #117

## 1.3.0
- Added support for landscape screenshots #66
- Added support for flavors #55
- Modified no-frame behavior and various improvements

## 1.2.0
- Added archive feature to collect screenshots of all runs for reporting, etc... #77 #81
- Improved detection of adb path #79

## 1.1.1
- Fixed localization issue in test #19, #20
- Improved handling of locale for emulators and real devices

## 1.1.0
- Added record/compare feature to compare screenshots with previously recorded screenshots during a run. #65

## 1.0.2
- Fixed bug with parsing ios simulator info #73

## 1.0.1
- Fixed pedantic lint errors

## 1.0.0
- Added support for running on any device (real, emulator or simulator), whether booted or not, even if there are no supported screens (this requires marking unsupported devices with 'frame: false').
- Added support for FrameIt 'text and background' feature #61
- Removed requirement that no devices/emulators be running at startup #63
- Allow screenshots to be configured with multiple locales and deliberately run into flutter driver bug (with warning) #20
- Added feature to use running emulators/simulators or boot required ones #56
- Added flutter tools daemon to manage real devices, android emulators, and manage boot state of emulators and ios simulators
- Added wait-for-event to daemon client (for use in waiting for emulator to shutdown)
- Added wait-for-locale-change using syslog
- Re-organized as library
- Changed from using positional optional params to named optional params in public API (breaking change)

## 0.2.1
- Added support for iPhone Xs and iPhone Xs Max

## 0.2.0
- Added option to control framing at device level  
(breaking change)
- Added screen for iPad Pro (12.9-inch) (3rd generation)

## 0.1.8
- Added support default screen for android tablet
- Added feature to make screenshots environment available to tests
- Improved messaging in validator
- Added feature to auto-select black/white color of statusbar
- Added feature to set default background color
- Fixed problem with selecting simulators when no default available

## 0.1.7
- Added check for highest available android emulator for a device
- Added check for 'adb' in PATH

## 0.1.6
- Improved handling of iOS simulator info provided by Apple

## 0.1.5

- Updated parser for iOS simulators to work with all Apple machines
- Added check for no running emulators and simulators on startup
- Added check to wait for emulator to stop

## 0.1.4

- Bypasses changing locales if running in only one locale
- Issues warning about running flutter driver in multiple locales  
  See issue: <https://github.com/flutter/flutter/issues/27785> for details.

## 0.1.3

- Added support for multiple locales and additional screens for devices

## 0.1.2

- Added configuration validation

## 0.1.1

- Fixed parsing of simulator info on some MacOS's

## 0.1.0

- Cleanup and release

## 0.0.2

- Added support for iPad screenshots

## 0.0.1

- Initial version
