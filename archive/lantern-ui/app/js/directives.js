'use strict';

var directives = angular.module('app.directives', [])
  .directive('compileUnsafe', function ($compile) {
    return function (scope, element, attr) {
      scope.$watch(attr.compileUnsafe, function (val, oldVal) {
        if (!val || (val === oldVal && element[0].innerHTML)) return;
        element.html(val);
        $compile(element)(scope);
      });
    };
  })
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
  .directive('onError', function ($parse) {
    return {
      link: function(scope, element, attrs) {
        element.bind('error', function() {
          scope.$apply(attrs.onError);
        });
      }
    };
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
