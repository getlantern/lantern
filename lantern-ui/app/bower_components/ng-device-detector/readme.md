#ng-device-detector
##Angular module to detect OS / Browser / Device

[![Build Status](https://travis-ci.org/srfrnk/ng-device-detector.svg?branch=master)](https://travis-ci.org/srfrnk/ng-device-detector)

Uses user-agent to set css classes or directly usable via JS.
See website: [http://srfrnk.github.io/ng-device-detector](http://srfrnk.github.io/ng-device-detector)

### Install
* Run $ bower install ng-device-detector --save
* Add script load to HTML:`<script type="text/javascript" src=".../re-tree.js"></script>`
* Add script load to HTML:`<script type="text/javascript" src=".../ng-device-detector.js"></script>`
* Add module to your app dependencies: `...angular.module("...", [..."ng.deviceDetector"...])...`
* To add classes - add directive like so- `<div ... device-detector ...>`
* To use directly add `"deviceDetector"` service to your injectors...

### deviceDetector service
Holds the following properties:
* raw : object : contains the raw values... for internal use mostly.
* os : string : name of current OS
* browser : string : name of current browser
* device : string : name of current device
 
### Support
At first I added just major browser, OS, device support.
With help from mariendries,javierprovecho and crisandretta more support was added.
[The current list of supported browser,OS, device can be easily viewed in here] (https://github.com/srfrnk/ng-device-detector/blob/master/ng-device-detector.js).

Pull-requests with new stuff will be highly appreciated :)

### Example

See [plunker](http://plnkr.co/edit/urqMI1?p=preview)

### License

[MIT License](//github.com/srfrnk/ng-device-detector/blob/master/license.txt)
