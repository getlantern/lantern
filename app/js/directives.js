'use strict';

var directives = angular.module('app.directives', [])
  .directive('focusOn', function ($parse) {
    return function(scope, element, attr) {
      var val = $parse(attr['focusOn']);
      scope.$watch(val, function (val) {
        if (val) {
          element.focus();
        }
      });
    }
  })
  // directives to set focus to the select2 element when a value in the scope is truthy
  // and when a value in the scope flips from truthy to falsy (ui-select2 provides no API
  // for this - see https://github.com/angular-ui/ui-select2/issues/60)
  .directive('select2FocusOn', function ($parse, $timeout) {
    return function(scope, element, attr) {
      var val = $parse(attr['select2FocusOn']);
      scope.$watch(val, function (val) {
        if (val) {
          $timeout(function () {
            element.select2('focus', true);
          }, 0);
        }
      });
    }
  })
  .directive('select2FocusWhenCleared', function ($parse, $timeout) {
    return function(scope, element, attr) {
      var val = $parse(attr['select2FocusWhenCleared']);
      scope.$watch(val, function (val, oldVal) {
        if (!val && oldVal) {
          element.select2('focus', true);
        }
      });
    }
  });

// XXX https://github.com/angular/angular.js/issues/1050#issuecomment-9650293
angular.forEach(['x', 'y', 'cx', 'cy', 'd', 'fill', 'r'], function(name) {
  var ngName = 'ng' + name[0].toUpperCase() + name.slice(1);
  directives.directive(ngName, function() {
    return function(scope, element, attrs) {
      attrs.$observe(ngName, function(value) {
        attrs.$set(name, value); 
      })
    };
  });
});
