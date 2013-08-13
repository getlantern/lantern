(function(angular) {
'use strict';

angular.module('angulartics.ga', ['angulartics'])
  .config(['$analyticsProvider', function($analyticsProvider) {

    $analyticsProvider.registerPageTrack(function(path) {
    	if (window._gaq) window._gaq.push(['_trackPageview', path]);
    	if (window.ga) ga('send', 'pageview', path);
    });

    $analyticsProvider.registerEventTrack(function(action, properties) {
      if (window._gaq) window._gaq.push(['_trackEvent', properties.category, action, properties.label, properties.value]);
      if (window.ga) window.ga('send', 'event', properties.category, action, properties.label, properties.value);
    });

  }]);

})(angular);
