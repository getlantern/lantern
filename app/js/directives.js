'use strict';

angular.module('app.directives', [])
  .directive('focusOn', ['$parse', function($parse) {
    return function(scope, element, attr) {
      var val = $parse(attr['focusOn']);
      scope.$watch(val, function(val) {
        if (val) {
          element.focus();
        }
      });
    }
  }]);
