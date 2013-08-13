(function(angular) {
'use strict';

angular.module('angulartics', [])
  .provider('$analytics', function() {
    var settings = { tracking: { auto: true } };

    var api = {
      settings: settings,
      pageTrack: angular.noop,
      eventTrack: angular.noop
    };

    var registerPageTrack = function(fn) {
      api.pageTrack = fn;
    };
    var registerEventTrack = function(fn) {
      api.eventTrack = fn;
    };

    return {
      $get: function() { return api; },
      virtualPageviews: function(value) { this.settings.tracking.auto = value; },
      settings: settings,
      registerPageTrack: registerPageTrack,
      registerEventTrack: registerEventTrack
    };
  })

  .run(['$rootScope', '$location', '$analytics', '$log', function($rootScope, $location, $analytics, $log) {
    if ($analytics.settings.tracking.auto) {
      $rootScope.$on('$routeChangeStart', function() {
        $analytics.pageTrack($location.url());
      });
    }
  }])

  .directive('analyticsOn', ['$analytics', function($analytics) {

    function isCommand(element) {
      return ['a:','button:submit','input:button','input:submit'].indexOf(
        element.tagName.toLowerCase()+':'+(element.type||'')) >= 0;
    }

    function inferEventType(element) {
      if (isCommand(element)) return 'click';
      return 'click';
    }

    function inferEventName(element) {
      if (isCommand(element)) return element.innerText || element.value;
      return element.id || element.name || element.tagName;
    }

    function isProperty(name) {
      return name.substr(0, 9) === 'analytics' && ['on', 'event'].indexOf(name.substr(10)) === -1;
    }

    return {
      restrict: 'A',
      scope: false,
      link: function($scope, $element, $attrs) {
        var eventType = $attrs.analyticsOn || inferEventType($element[0]),
            eventName = $attrs.analyticsEvent || inferEventName($element[0]);

        var properties = {};
        angular.forEach($attrs.$attr, function(attr, name) {
          if (isProperty(attr)) {
            properties[name.slice(9).toLowerCase()] = $attrs[name];
          }
        });

        angular.element($element[0]).bind(eventType, function() {
          $analytics.eventTrack(eventName, properties);
        });
      }
    };
  }]);

})(angular);
