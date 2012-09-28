'use strict';

function RootCtrl($scope, syncedModel) {
  var model = $scope.model = syncedModel.model,
      connected = $scope.connected = syncedModel.connected;
}

function UnlockSettingsCtrl($scope, $http, logFactory, SETTINGS_STATE) {
  var log = logFactory('UnlockSettingsCtrl');
  $scope.show = false;
  $scope.$watch('model.settings.state', function(val) {
    $scope.show = val == SETTINGS_STATE.LOCKED;
  });

  $scope.submit = function(password) {
    $http.post('/api/unlockSettings?password='+encodeURIComponent(password))
      .success(function(data, status, headers, config) {
        log.debug('password valid');
        // XXX need to reset any form state?
      })
      .error(function(data, status, headers, config) {
        $scope.unlockForm.password.$error = {invalid: true};
        $scope.unlockForm.password.$pristine = true;
      });
  };
}

function CorruptSettingsCtrl($scope, $http, logFactory, SETTINGS_STATE) {
  var log = logFactory('CorruptSettingsCtrl');
  $scope.notifyLanternDevs = true;
  $scope.show = false;
  $scope.$watch('model.settings.state', function(val) {
    $scope.show = val == SETTINGS_STATE.CORRUPT;
  });

  $scope.maybeNotify = function() {
    if ($scope.notifyLanternDevs) {
      log.warn('Notify Lantern developers not yet implemented');
    }
  };

  function handleError(data, status, headers, config) {
    $scope.error = true;
  }

  $scope.reset = function() {
    $scope.error = false;
    $http.post('/api/resetSettings')
      .success(function(data, status, headers, config) {
        log.debug('reset settings');
      })
      .error(handleError);
  };

  $scope.quit = function() {
    $scope.error = false;
    $http.post('/api/quit')
      .success(function(data, status, headers, config) {
        log.debug('quit');
      })
      .error(handleError);
  };
}

function DebugCtrl($scope, debug, logFactory) {
  var log = logFactory('DebugCtrl');
  $scope.debug = debug;
}
