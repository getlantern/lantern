'use strict';

function RootCtrl($scope, logFactory, modelSrvc, $http) {
  var log = logFactory('RootCtrl'),
      model = $scope.model = modelSrvc.model,
      connected = $scope.connected = modelSrvc.connected;
  $scope.modelSrvc = modelSrvc;

  $scope.notifyLanternDevs = true;
  $scope.maybeNotify = function() {
    if ($scope.notifyLanternDevs) {
      log.warn('Notify Lantern developers not yet implemented');
    }
  };

  // sub-controllers can override this
  $scope.errorHandler = function() {
    //log.debug('Got error:', arguments);
    $scope.error = true;
  }

  $scope.refresh = function() {
    location.reload(true);
  };

  $scope.reset = function() {
    $scope.error = false;
    $http.post('/api/resetSettings')
      .success(function(data, status, headers, config) {
        log.debug('Reset settings');
      })
      .error($scope.errorHandler);
  };

  $scope.quit = function() {
    $scope.error = false;
    $http.post('/api/quit')
      .success(function(data, status, headers, config) {
        log.debug('Quit');
      })
      .error($scope.errorHandler);
  };
}

function SanityCtrl($scope, modelSrvc) {
  $scope.show = false;
  $scope.modelSane = modelSrvc.sane;
  $scope.$watch('modelSane()', function(sane) {
    $scope.show = !sane;
  });
}

function SettingsCouldNotLoadCtrl($scope, SETTINGS_STATE) {
  $scope.show = false;
  $scope.$watch('model.settings.state', function(val) {
    $scope.show = val == SETTINGS_STATE.couldNotLoad;
  });
}

function SettingsLockedCtrl($scope, $http, apiSrvc, logFactory, SETTINGS_STATE) {
  var log = logFactory('SettingsLockedCtrl');
  $scope.show = false;
  $scope.$watch('model.settings.state', function(val) {
    $scope.show = val == SETTINGS_STATE.locked;
  });

  $scope.submit = function(password) {
    $http.post(apiSrvc.urlfor('settings/unlock', {password: password}))
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

function SetupSetPasswordCtrl($scope, $http, apiSrvc, logFactory, SETUP_SCREEN) {
  var log = logFactory('SetupSetPasswordCtrl');
  $scope.show = false;
  $scope.$watch('model.setupScreen', function(val) {
    $scope.show = val == SETUP_SCREEN.setPassword;
  });

  function validate() {
    var pw1 = $scope.setPasswordForm.password1,
        pw2 = $scope.setPasswordForm.password2;
    $scope.setPasswordForm.$valid = pw2.$valid = pw1.$viewValue == pw2.$viewValue;
    $scope.setPasswordForm.$invalid = pw2.$invalid = !pw2.$valid;
  }
  $scope.$watch('setPasswordForm.password2.$viewValue', validate);
  $scope.$watch('setPasswordForm.password1.$viewValue', validate);

  $scope.submit = function(password) {
    $http.post(apiSrvc.urlfor('settings/secure', {password: password}))
      .success(function(data, status, headers, config) {
        log.debug('password set');
        // XXX need to reset any form state?
      })
      .error(function(data, status, headers, config) {
        log.debug('password set failed');
      });
  };
}


function DevCtrl($scope, debug, logFactory, cometdSrvc, modelSrvc) {
  var log = logFactory('DevCtrl'),
      model = $scope.model = modelSrvc.model,
      lastModel = $scope.lastModel = angular.copy(model);
  $scope.show = debug;

  $scope.$watch('model', function() {
    syncObject('', model, lastModel);
  }, true);

  function syncObject(parent, src, dst) {
    for (var name in src) {
      var path = (parent ? parent + '.' : '') + name;
      if (src[name] === dst[name]) {
        // do nothing we are in sync
      } else if (typeof src[name] == 'object') {
        // we are an object, so we need to recurse
        syncObject(path, src[name], dst[name] || {});
      } else {
        dst[name] = angular.copy(src[name]);
        cometdSrvc.publish('/sync', {path:path, value:src[name]});
      }
    }
  }
}
