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

Get new flutter screenshot, add new images to lib/resources, add new screen to lib/resources/screens.yaml. Then run frame.dart to see the result of framing.

Sample run of frame.dart:
```
pub run frame.dart -s screenshot_Nexus_6P.png -d 'Nexus 6P'
or 
dart frame.dart -s screenshot_Nexus_6P.png -d 'Nexus 6P'
```

After framing is working create a PR.

Please include a description of how you sourced the images used. If you are the author of the images, please include the source files (preferably in Sketch format) you used to create the images in the [assets](https://github.com/mmcc007/screenshots/tree/master/assets) directory.