# Creating a new screen

Inserting a flutter screenshot from a device into a frame requires several images specific to the device and the screen size of the device:

1. the frame
1. the navigation bar (if android)
1. the status bar

Facebook provides frames suitable for upload to stores at:
https://facebook.design/devices

Locate a frame with a screen size that matches your device from among Facebook frames.

The images for the navigation and status bars have to be created or sourced on web. In the past, I have found navigation and status bars created in Sketch on web. Had to resize some to fit the device screen size and then convert to PNG.

Once all the images are in place, a new screen can be configured in screens.yaml. Then can experiment with parameters in screens.yaml, by running [frame.dart](frame.dart), until the screenshot is correct.

The steps for adding a new screen:
1. Add new images to lib/resources for status bar, navigation bar(if android) and frame
1. Add new screen to lib/resources/screens.yaml
1. Get new flutter screenshot from a device matching the new screen
1. Repeat calls to frame.dart to generate new frame until screen fits frame. 
    1. Adjust new screen parameters in screens.yaml to fit screen into device frame
    1. May need to modify images for status bar and navigation bar.
1. Commit new images and screen config
 
Sample run of frame.dart:
```
pub run frame.dart -s screenshot_Nexus_6P.png -d 'Nexus 6P'
or 
dart frame.dart -s screenshot_Nexus_6P.png -d 'Nexus 6P'
```
where screenshot_Nexus_6P.png is a flutter screenshot from a device/emulator/simulator matching the new screen size and 'Nexus 6P' is a device that matches the size of the newly entered screen in screens.yaml.  
This utility can be used to fine-tune the parameters in screens.yaml to get the correct fit for screenshot, status bar, and navigation bar (if android) in device frame.

After framing is working create a PR.

Please include a description of how you sourced the images used. If you are the author of the images, please include the source files (preferably in Sketch format) you used to create the images in the [assets](https://github.com/mmcc007/screenshots/tree/master/assets) directory.