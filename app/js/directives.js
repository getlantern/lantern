'use strict';
/* http://docs-next.angularjs.org/api/angular.module.ng.$compileProvider.directive */


angular.module('myApp.directives', []).
  directive('appVersion', ['version', function(version) {
    return function(scope, elm, attrs) {
      elm.text(version);
    };
  }]);
