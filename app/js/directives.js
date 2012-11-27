'use strict';

angular.module('app.directives', []).
  directive('blockInput', function() {
    return function(scope, elm, attrs) {
      elm.css({
        'z-index': 10000,
        position: 'fixed',
        top: 0,
        bottom: 0,
        left: 0,
        right: 0,
        // XXX take these as options?
        'text-align': 'center',
        'background-color': '#fff',
        filter: 'progid:DXImageTransform.Microsoft.Alpha(Opacity=90)', // IE8
        opacity: 0.9
      });
    };
  })
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
