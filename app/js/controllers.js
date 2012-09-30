'use strict';

function RootCtrl($scope, logFactory, modelSrvc, $http, apiSrvc, MODE) {
  var log = logFactory('RootCtrl'),
      model = $scope.model = modelSrvc.model,
      connected = $scope.connected = modelSrvc.connected;
  $scope.modelSrvc = modelSrvc;

  $scope.inGiveMode = function() {
    return model.settings.mode == MODE.give;
  };

  $scope.inGetMode = function() {
    return model.settings.mode == MODE.get;
  };

  $scope.notifyLanternDevs = true; // XXX find a better place for this?
  $scope.$watch('model.settings.autoReport', function(val) {
    if (typeof val == 'boolean') {
      $scope.notifyLanternDevs = val;
    }
  });
  $scope.maybeNotify = function() {
    if ($scope.notifyLanternDevs) {
      log.warn('Notify Lantern developers not yet implemented');
    }
  };

  $scope.refresh = function() {
    location.reload(true);
  };

  $scope.reset = function() {
    $http.post(apiSrvc.urlfor('reset'))
      .success(function(data, status, headers, config) {
        log.debug('Reset');
      })
      .error(function(data, status, headers, config) {
        log.debug('Reset failed'); // XXX
      });
  };

  $scope.quit = function() {
    $http.post(apiSrvc.urlfor('quit'))
      .success(function(data, status, headers, config) {
        log.debug('Quit');
      })
      .error(function(data, status, headers, config) {
        log.debug('Quit failed'); // XXX
      });
  };
}

function SanityCtrl($scope, modelSrvc) {
  $scope.show = false;
  $scope.modelSane = modelSrvc.sane;
  $scope.$watch('modelSane()', function(sane) {
    $scope.show = !sane;
  });
}

function SettingsLoadFailureCtrl($scope, MODAL) {
  $scope.show = false;
  $scope.$watch('model.modal', function(val) {
    $scope.show = val == MODAL.settingsLoadFailure;
  });
}

function SettingsUnlockCtrl($scope, modelSrvc, $http, apiSrvc, logFactory, MODAL) {
  var log = logFactory('SettingsUnlockCtrl'),
      model = $scope.model = modelSrvc.model;
  $scope.show = false;
  $scope.$watch('model.modal', function(val) {
    $scope.show = val == MODAL.settingsUnlock;
  });

  $scope.password = '';

  $scope.submit = function() {
    $scope.error = false;
    $http.post(apiSrvc.urlfor('settings/unlock', {password: $scope.password}))
      .success(function(data, status, headers, config) {
        log.debug('password valid');
        // XXX need to reset any form state?
      })
      .error(function(data, status, headers, config) {
        $scope.error = true;
        $scope.unlockForm.password.$pristine = true;
      });
  };
}

function PasswordCreateCtrl($scope, $http, apiSrvc, logFactory, MODAL) {
  var log = logFactory('PasswordCreateCtrl');
  $scope.show = false;
  $scope.$watch('model.modal', function(val) {
    $scope.show = val == MODAL.passwordCreate;
  });

  $scope.password1 = '';
  $scope.password2 = '';
  function validate() {
    // XXX find out the right way to do this
    var pw1ctrl = $scope.passwordCreateForm.password1,
        pw2ctrl = $scope.passwordCreateForm.password2,
        valid = $scope.password1 == $scope.password2;
    $scope.passwordCreateForm.$valid = pw2ctrl.$valid = valid;
    $scope.passwordCreateForm.$invalid = pw2ctrl.$invalid = !valid;
  }
  $scope.$watch('password1', validate);
  $scope.$watch('password2', validate);

  $scope.submit = function() {
    $http.post(apiSrvc.urlfor('passwordCreate', {password: $scope.password1}))
      .success(function(data, status, headers, config) {
        log.debug('password set');
        // XXX need to reset any form state?
      })
      .error(function(data, status, headers, config) {
        log.debug('password set failed');
      });
  };
}

function WelcomeCtrl($scope, modelSrvc, $http, apiSrvc, logFactory, MODAL) {
  var log = logFactory('WelcomeCtrl'),
      model = $scope.model = modelSrvc.model;
  $scope.show = false;
  $scope.$watch('model.modal', function(val) {
    $scope.show = val == MODAL.welcome;
  });

  function makeSetModeFunc(mode) {
    return function() {
      $http.post(apiSrvc.urlfor('settings/', {mode: mode}))
        .success(function(data, status, headers, config) {
          log.debug('set', mode, 'mode');
        })
        .error(function(data, status, headers, config) {
          log.debug('set', mode, 'mode failed');
        });
    };
  }

  $scope.setGiveMode = makeSetModeFunc('give');
  $scope.setGetMode = makeSetModeFunc('get');
}

function SigninCtrl($scope, modelSrvc, $http, apiSrvc, logFactory, MODAL) {
  var log = logFactory('SigninCtrl'),
      model = $scope.model = modelSrvc.model;
  $scope.show = false;
  $scope.$watch('model.modal', function(val) {
    $scope.show = val == MODAL.signin;
  });

  $scope.userid = '';
  $scope.password = '';
  $scope.savePassword = '';
  $scope.signinError = false;
  $scope.$watch('model.settings.userid', function(val) {
    $scope.userid = val;
  });
  $scope.$watch('model.settings.savePassword', function(val) {
    $scope.savePassword = !!val;
  });
  function hideSigninStatus() {
    $scope.showSigninStatus = false;
  }
  $scope.$watch('userid', hideSigninStatus);
  $scope.$watch('password', hideSigninStatus);

  $scope.submit = function() {
    $scope.signinError = false;
    $scope.showSigninStatus = true;
    $scope.signinStatusKey = 'SIGNIN_STATUS_SIGNING_IN';
    var params = {userid: $scope.userid, password: $scope.password};
    if ($scope.savePassword) params['savePassword'] = 1;
    $http.post(apiSrvc.urlfor('signin', params))
      .success(function(data, status, headers, config) {
        log.debug('signin');
        hideSigninStatus();
      })
      .error(function(data, status, headers, config) {
        log.debug('signin failed');
        $scope.signinError = true;
        switch (status) {
          case 401:
            $scope.signinStatusKey = 'SIGNIN_STATUS_BAD_CREDENTIALS';
            break;
          case 403:
            $scope.signinStatusKey = 'SIGNIN_STATUS_NOT_AUTHORIZED';
            break;
          default:
            $scope.signinStatusKey = 'UNEXPECTED_ERROR';
        }
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
