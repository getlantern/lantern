/**
 * @license Angulartics v0.8.4
 * (c) 2013 Luis Farzati http://luisfarzati.github.io/angulartics
 * License: MIT
 */
(function (angular) {
'use strict';

/**
 * @ngdoc overview
 * @name angulartics.scroll
 * Provides an implementation of jQuery Waypoints (http://imakewebthings.com/jquery-waypoints/)
 * for use as a valid DOM event in analytics-on.
 */
angular.module('angulartics.scroll', ['angulartics'])
.directive('analyticsOn', ['$analytics', function ($analytics) {
  function isProperty(name) {
    return name.substr(0, 8) === 'scrollby';
  }
  function cast(value) {
    if (['', 'true', 'false'].indexOf(value) > -1) {
      return value.replace('', 'true') === 'true';
    }
    return value;
  }

  return {
    restrict: 'A',
    priority: 5,
    scope: false,
    link: function ($scope, $element, $attrs) {
      if ($attrs.analyticsOn !== 'scrollby') return;

      var properties = { continuous: false, triggerOnce: true };
      angular.forEach($attrs.$attr, function(attr, name) {
        if (isProperty(attr)) {
          properties[name.slice(8,9).toLowerCase()+name.slice(9)] = cast($attrs[name]);
        }
      });

      $($element[0]).waypoint(function () {
        this.dispatchEvent(new Event('scrollby'));
      }, properties);
    }
  };
}]);
})(angular);