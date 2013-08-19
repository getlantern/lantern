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
  // XXX hack to set focus to select2 element since ui-select2 provides no API for this
  //     see https://github.com/angular-ui/ui-select2/issues/60
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
