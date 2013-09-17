/**
 * @license Angulartics v0.8.4
 * (c) 2013 Luis Farzati http://luisfarzati.github.io/angulartics
 * Universal Analytics update contributed by http://github.com/willmcclellan
 * License: MIT
 */
(function(angular) {
'use strict';

/**
 * @ngdoc overview
 * @name angulartics.google.analytics
 * Enables analytics support for Google Analytics (http://google.com/analytics)
 */
angular.module('angulartics.google.analytics', ['angulartics'])
.config(['$analyticsProvider', function ($analyticsProvider) {

  // GA already supports buffered invocations so we don't need
  // to wrap these inside angulartics.waitForVendorApi

  $analyticsProvider.registerPageTrack(function (path) {
    if (window._gaq) _gaq.push(['_trackPageview', path]);
    if (window.ga) ga('send', 'pageview', path);
  });

  $analyticsProvider.registerEventTrack(function (action, properties) {
    if (window._gaq) _gaq.push(['_trackEvent', properties.category, action, properties.label, properties.value]);
    if (window.ga) ga('send', 'event', properties.category, action, properties.label, properties.value);
  });
  
}]);
})(angular);