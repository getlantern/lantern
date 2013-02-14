'use strict';

var directives = angular.module('app.directives', [])
  .directive('updateOnBlur', function() {
    return {
      restrict: 'EA',
      require: 'ngModel',
      link: function(scope, element, attrs, ctrl) {
        element.unbind('input').unbind('keydown').unbind('change');
        element.bind('blur', function() {
          scope.$apply(function() {
            ctrl.$setViewValue(element.val());
          });
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
