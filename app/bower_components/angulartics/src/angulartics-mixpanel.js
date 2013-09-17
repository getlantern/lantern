/**
 * @license Angulartics v0.8.4
 * (c) 2013 Luis Farzati http://luisfarzati.github.io/angulartics
 * Contributed by http://github.com/L42y
 * License: MIT
 */
(function(angular) {
'use strict';

/**
 * @ngdoc overview
 * @name angulartics.mixpanel
 * Enables analytics support for Mixpanel (http://mixpanel.com)
 */
angular.module('angulartics.mixpanel', ['angulartics'])
.config(['$analyticsProvider', function ($analyticsProvider) {
  $analyticsProvider.registerPageTrack(function (path) {
    mixpanel.track_pageview(path);
  });

  $analyticsProvider.registerEventTrack(function (action, properties) {
    mixpanel.track(action, properties);
  });
}]);
})(angular);