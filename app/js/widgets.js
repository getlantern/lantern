'use strict';
/* http://docs.angularjs.org/#!angular.widget */

angular.module('myApp.widgets', [], function() {
  // temporary hack until we have proper directive injection.
  angular.directive('app-version', function() {
    return ['version', '$element', function(version, element) {
      element.text(version);
    }];
  });
});
