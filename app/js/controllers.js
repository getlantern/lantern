'use strict';

function RootCtrl($scope, logFactory, modelSrvc, cometdSrvc, langSrvc, $http, apiSrvc, ENUMS) {
  var log = logFactory('RootCtrl'),
      model = $scope.model = modelSrvc.model,
      MODE = ENUMS.MODE,
      STATUS_GTALK = ENUMS.STATUS_GTALK;
  $scope.modelSrvc = modelSrvc;
  $scope.cometdSrvc = cometdSrvc;

  angular.forEach(ENUMS, function(val, key) {
    $scope[key] = val;
  });

  // XXX better place for these?

  $scope.lang = langSrvc.lang;
  $scope.direction = langSrvc.direction;

  $scope.$watch('model.settings.mode', function modeChanged(val) {
    $scope.inGiveMode = val == MODE.give;
    $scope.inGetMode = val == MODE.get;
  });

  $scope.$watch('connectivity.gtalk', function gtalkChanged(val) {
    $scope.gtalkNotConnected = val == STATUS_GTALK.notConnected;
    $scope.gtalkConnecting = val == STATUS_GTALK.connecting;
    $scope.gtalkConnected = val == STATUS_GTALK.connected;
  });

  $scope.notifyLanternDevs = true;
  $scope.$watch('model.settings.autoReport', function autoReportChanged(val) {
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

  $scope.continue_ = function() {
    $http.post(apiSrvc.urlfor('continue'))
      .success(function(data, status, headers, config) {
        log.debug('Continue');
      })
      .error(function(data, status, headers, config) {
        log.debug('Continue failed'); // XXX
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

  $scope.changeSetting = function(key, val) {
    var params = {};
    params[key] = val;
    $http.post(apiSrvc.urlfor('settings/', params))
      .success(function(data, status, headers, config) {
        log.debug('Changed setting', key, 'to', val);
      })
      .error(function(data, status, headers, config) {
        log.debug('Changed setting', key, 'to', val, 'failed');
      });
  };
}

function WaitingForLanternCtrl($scope, logFactory) {
  var log = logFactory('SettingsUnlockCtrl');
  $scope.show = true;
  $scope.$on('cometdConnected', function() {
    log.debug('cometdConnected');
    $scope.show = false;
    $scope.$apply();
  });
  $scope.$on('cometdDisconnected', function () {
    log.debug('cometdDisconnected');
    $scope.show = true;
    $scope.$apply();
  });
}

/*
function SanityCtrl($scope, modelSrvc) {
  $scope.show = false;
  $scope.modelSane = modelSrvc.sane;
  $scope.$watch('modelSane()', function(sane) {
    $scope.show = !sane;
  });
}
*/

function SettingsLoadFailureCtrl($scope, MODAL) {
  $scope.show = false;
  $scope.$watch('model.modal', function modalChanged(val) {
    $scope.show = val == MODAL.settingsLoadFailure;
  });
}

function SettingsUnlockCtrl($scope, $http, apiSrvc, logFactory, MODAL) {
  var log = logFactory('SettingsUnlockCtrl');

  $scope.show = false;
  $scope.$watch('model.modal', function modalChanged(val) {
    $scope.show = val == MODAL.settingsUnlock;
  });

  $scope.password = '';

  $scope.settingsUnlock = function() {
    $scope.error = false;
    $http.post(apiSrvc.urlfor('settings/unlock', {password: $scope.password}))
      .success(function(data, status, headers, config) {
        log.debug('password valid');
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
  $scope.$watch('model.modal', function modalChanged(val) {
    $scope.show = val == MODAL.passwordCreate;
  });

  $scope.password1 = '';
  $scope.password2 = '';
  function validate() {
    // XXX Angular way of doing this?
    var pw1ctrl = $scope.passwordCreateForm.password1,
        pw2ctrl = $scope.passwordCreateForm.password2,
        valid = $scope.password1 == $scope.password2;
    $scope.passwordCreateForm.$valid = pw2ctrl.$valid = valid;
    $scope.passwordCreateForm.$invalid = pw2ctrl.$invalid = !valid;
  }
  $scope.$watch('password1', validate);
  $scope.$watch('password2', validate);

  $scope.passwordCreate = function() {
    $http.post(apiSrvc.urlfor('passwordCreate', {password: $scope.password1}))
      .success(function(data, status, headers, config) {
        log.debug('Password create');
      })
      .error(function(data, status, headers, config) {
        log.debug('Password create failed'); // XXX
      });
  };
}

function WelcomeCtrl($scope, modelSrvc, logFactory, MODAL) {
  var log = logFactory('WelcomeCtrl'),
      model = $scope.model = modelSrvc.model;
  $scope.show = false;
  $scope.$watch('model.modal', function modalChanged(val) {
    $scope.show = val == MODAL.welcome;
  });
}

function LangChooserCtrl($scope) {
  $scope.show = false;
  $scope.$watch('model.modal', function(val) {
    $scope.show = !!val;
  });
}

function SigninCtrl($scope, $http, modelSrvc, apiSrvc, logFactory, MODAL, STATUS_GTALK) {
  var log = logFactory('SigninCtrl'),
      model = modelSrvc.model;

  $scope.show = false;
  $scope.$watch('model.modal', function modalChanged(val) {
    $scope.show = val == MODAL.signin;
  });

  $scope.userid = null;
  $scope.password = '';
  $scope.savePassword = true;
  $scope.$watch('model.settings.savePassword', function savePasswordChanged(val) {
    if (typeof val == 'boolean')
      $scope.savePassword = val;
  });
  $scope.$watch('model.settings.userid', function useridChanged(val) {
    if ($scope.userid == null && val)
      $scope.userid = val;
  });
  $scope.signinError = false;
  $scope.submitButtonLabelKey = 'SIGN_IN';
  $scope.$watch('model.connectivity.gtalk', function gtalkChanged(val) {
    if (val == STATUS_GTALK.notConnected) {
      $scope.submitButtonLabelKey = 'SIGN_IN';
      $scope.disableSubmit = false;
    } else if (val == STATUS_GTALK.connecting) {
      $scope.submitButtonLabelKey = 'SIGNING_IN';
      $scope.disableSubmit = true;
    } else if (val == STATUS_GTALK.connected) {
      $scope.submitButtonLabelKey = 'SIGNED_IN';
      $scope.disableSubmit = true;
    }
  });

  var signinStatusMap = {
    401: 'SIGNIN_STATUS_BAD_CREDENTIALS',
    403: 'SIGNIN_STATUS_NOT_AUTHORIZED',
    503: 'SIGNIN_STATUS_SERVICE_UNAVAILABLE'
  };
  function hideSigninStatus() {
    $scope.showSigninStatus = false;
  }
  $scope.$watch('userid', hideSigninStatus);
  $scope.$watch('password', hideSigninStatus);
  $scope.needPassword = true;
  $scope.$watch('savePassword', function savePasswordChanged(val) {
    $scope.needPassword = !(val && (model.settings || {}).passwordSaved);
  });
  $scope.$watch('model.settings.passwordSaved', function passwordSavedChanged(val) {
    $scope.needPassword = !(val && $scope.savePassword);
  });

  $scope.signin = function() {
    $scope.signinError = false;
    $scope.showSigninStatus = false;
    $scope.disableSubmit = true;
    var params = {userid: $scope.userid};
    if ($scope.needPassword) {
      params['password'] = $scope.password;
    }
    $http.post(apiSrvc.urlfor('signin', params))
      .success(function(data, status, headers, config) {
        log.debug('signin');
      })
      .error(function(data, status, headers, config) {
        log.debug('signin failed');
        $scope.signinError = true;
        $scope.showSigninStatus = true;
        $scope.disableSubmit = false;
        $scope.signinStatusKey = signinStatusMap[status] || 'UNEXPECTED_ERROR';
      });
  };
}

function GtalkUnreachableCtrl($scope, apiSrvc, $http, logFactory, MODAL) {
  var log = logFactory('GtalkUnreachableCtrl');
  $scope.show = false;
  $scope.$watch('model.modal', function modalChanged(val) {
    $scope.show = val == MODAL.gtalkUnreachable;
  });
}

function SystemProxyCtrl($scope, $http, apiSrvc, logFactory, MODAL) {
  var log = logFactory('SystemProxyCtrl');

  $scope.show = false;
  $scope.$watch('model.modal', function modalChanged(val) {
    $scope.show = val == MODAL.sysproxy;
  });

  $scope.systemProxy = true;
  $scope.submitButtonLabelKey = 'CONTINUE';
  $scope.disableSubmit = false;

  $scope.sysproxySet = function() {
    $scope.sysproxyError = false;
    $scope.disableSubmit = true;
    $scope.submitButtonLabelKey = 'CONFIGURING';
    var params = {systemProxy: $scope.systemProxy};
    $http.post(apiSrvc.urlfor('settings/', params))
      .success(function(data, status, headers, config) {
        log.debug('set systemProxy to', $scope.systemProxy);
      })
      .error(function(data, status, headers, config) {
        log.debug('set systemProxy failed');
        $scope.sysproxyError = true;
      }).then(function(){
        $scope.submitButtonLabelKey = 'CONTINUE';
        $scope.disableSubmit = false;
      });
  };
}

function FinishedCtrl($scope, MODAL) {
  $scope.show = false;
  $scope.$watch('model.modal', function modalChanged(val) {
    $scope.show = val == MODAL.finished;
  });
}

function DevCtrl($scope, debug, logFactory, cometdSrvc, modelSrvc) {
  var log = logFactory('DevCtrl'),
      model = modelSrvc.model,
      lastModel = modelSrvc.lastModel;
  $scope.debug = debug;

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
        if (!(name in dst)) dst[name] = {};
        syncObject(path, src[name], dst[name]);
      } else {
        log.debug('publishing: path:', path, 'value:', src[name]);
        cometdSrvc.publish('/sync', {path: path, value: src[name]});
        dst[name] = angular.copy(src[name]);
      }
    }
  }
}
