/**
 * @license Angulartics v0.8.4
 * (c) 2013 Luis Farzati http://luisfarzati.github.io/angulartics
 * License: MIT
 */
(function(angular) {
'use strict';

/**
 * @ngdoc overview
 * @name angulartics.segment.io
 * Enables analytics support for Segment.io (http://segment.io)
 */
angular.module('angulartics.segment.io', ['angulartics'])
.config(['$analyticsProvider', function ($analyticsProvider) {
  $analyticsProvider.registerPageTrack(function (path) {
    analytics.pageview(path);
  });

  $analyticsProvider.registerEventTrack(function (action, properties) {
    analytics.track(action, properties);
  });
}]);
})(angular);