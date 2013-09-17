/**
 * @license Angulartics v0.8.4
 * (c) 2013 Luis Farzati http://luisfarzati.github.io/angulartics
 * License: MIT
 */
(function(angular) {
'use strict';

/**
 * @ngdoc overview
 * @name angulartics.kissmetrics
 * Enables analytics support for KISSmetrics (http://kissmetrics.com)
 */
angular.module('angulartics.kissmetrics', ['angulartics'])
.config(['$analyticsProvider', function ($analyticsProvider) {

  // KM already supports buffered invocations so we don't need
  // to wrap these inside angulartics.waitForVendorApi

  $analyticsProvider.registerPageTrack(function (path) {
    _kmq.push(['record', 'Pageview', { 'Page': path }]);
  });

  $analyticsProvider.registerEventTrack(function (action, properties) {
    _kmq.push(['record', action, properties]);
  });
  
}]);
})(angular);