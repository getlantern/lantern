'use strict';

angular.module('app', ['app.i18n', 'app.filters', 'app.services', 'app.directives', 'ui'])
  .constant('debug', true)
  .constant('SETTINGS_STATE', {
    locked: 'locked',
    unlocked: 'unlocked',
    corrupt: 'corrupt'
  });
/*
  config(['$routeProvider', function($routeProvider) {
  $routeProvider.
    when('/status', {templateUrl: 'partials/status.html',   controller: StatusCtrl}).
    when('/settings', {templateUrl: 'partials/settings.html',   controller: SettingsCtrl}).
    when('/roster', {templateUrl: 'partials/roster.html', controller: RosterCtrl}).
    otherwise({redirectTo: '/status'});
}]);*/
