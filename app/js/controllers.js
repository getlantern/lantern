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

function DebugCtrl($scope, debug, logFactory) {
  var log = logFactory('DebugCtrl');
  $scope.debug = debug;
}
