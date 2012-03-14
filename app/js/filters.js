'use strict';
/* http://docs-next.angularjs.org/api/angular.module.ng.$filter */

angular.module('myApp.filters', []).
  filter('interpolate', ['version', function(version) {
    return function(text) {
      return String(text).replace(/\%VERSION\%/mg, version);
    }
  }]);
