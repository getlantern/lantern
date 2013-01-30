'use strict';

angular.module('app.directives', [])
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
  })
;
