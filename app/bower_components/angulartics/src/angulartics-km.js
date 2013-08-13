(function(angular) {
'use strict';

angular.module('angulartics.km', ['angulartics'])
  .config(['$analyticsProvider', function($analyticsProvider) {

    $analyticsProvider.registerPageTrack(function(path) {
      _kmq.push(['record', 'Pageview', { 'Page': path }]);
    });

    $analyticsProvider.registerEventTrack(function(action, properties) {
      _kmq.push(['record', action, properties]);
    });
  }]);

})(angular);
