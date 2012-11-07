'use strict';

// XXX use data-loading-text instead of submitButtonLabelKey below?
// see http://twitter.github.com/bootstrap/javascript.html#buttons

function RootCtrl(dev, sanity, $scope, logFactory, modelSrvc, cometdSrvc, langSrvc, $http, apiSrvc, ENUMS) {
  var log = logFactory('RootCtrl'),
      model = $scope.model = modelSrvc.model,
      MODE = ENUMS.MODE,
      STATUS_GTALK = ENUMS.STATUS_GTALK;
  $scope.modelSrvc = modelSrvc;
  $scope.cometdSrvc = cometdSrvc;
  $scope.dev = dev;

  angular.forEach(ENUMS, function(val, key) {
    $scope[key] = val;
  });

  // XXX better place for these?
  $scope.lang = langSrvc.lang;
  $scope.direction = langSrvc.direction;

  $scope.$watch('model.settings.mode', function(val) {
    $scope.inGiveMode = val == MODE.give;
    $scope.inGetMode = val == MODE.get;
  });

  $scope.$watch('connectivity.gtalk', function(val) {
    $scope.gtalkNotConnected = val == STATUS_GTALK.notConnected;
    $scope.gtalkConnecting = val == STATUS_GTALK.connecting;
    $scope.gtalkConnected = val == STATUS_GTALK.connected;
  });

  $scope.notifyLanternDevs = true;
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
    location.reload(true); // true to bypass cache and force request to server
  };

  $scope.reset = function() {
    $http.post(apiSrvc.urlfor('reset'))
      .success(function(data, status, headers, config) {
        log.debug('Reset');
        $scope.$broadcast('reset');
      })
      .error(function(data, status, headers, config) {
        log.debug('Reset failed'); // XXX
      });
  };

  $scope.interaction = function(interaction, extra) {
    var params = angular.extend({interaction: interaction}, extra || {});
    $http.post(apiSrvc.urlfor('interaction', params))
      .success(function(data, status, headers, config) {
        log.debug('interaction');
      })
      .error(function(data, status, headers, config) {
        log.debug('interaction failed'); // XXX
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
  var log = logFactory('WaitingForLanternCtrl');
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

function SanityCtrl($scope, sanity, modelSrvc, cometdSrvc, APIVER_REQUIRED, MODAL, apiVerLabel, logFactory) {
  var log = logFactory('SanityCtrl');
  $scope.sanity = sanity;

  $scope.show = false;
  $scope.$watch('sanity.value', function(val) {
    log.debug('sanity.value', val);
    if (!val) {
      log.warn('sanity false, disconnecting');
      modelSrvc.disconnect();
      modelSrvc.model.modal = MODAL.none;
      $scope.show = true;
    }
  });

  $scope.$watch('model.version.current.api', function(val) {
    if (typeof val == 'undefined') return;
    if (val.major != APIVER_REQUIRED.major ||
        val.minor != APIVER_REQUIRED.minor) {
      sanity.value = false;
      log.error('Available API version', val,
        'incompatible with required version', APIVER_REQUIRED);
    }
    // XXX required by apiSrvc. Better place for this?
    apiVerLabel.value = val.major+'.'+val.minor+'.'+val.patch;
  }, true);
}

function SettingsLoadFailureCtrl($scope, MODAL) {
  $scope.show = false;
  $scope.$watch('model.modal', function(val) {
    $scope.show = val == MODAL.settingsLoadFailure;
  });
}

function SettingsUnlockCtrl($scope, $http, apiSrvc, logFactory, MODAL) {
  var log = logFactory('SettingsUnlockCtrl');

  $scope.show = false;
  $scope.$watch('model.modal', function(val) {
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
  $scope.$watch('model.modal', function(val) {
    $scope.show = val == MODAL.passwordCreate;
  });

  $scope.password1 = '';
  $scope.password2 = '';
  // XXX don't allow weak passwords?
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
    $http.post(apiSrvc.urlfor('passwordCreate',
        {password1: $scope.password1, password2: $scope.password2}))
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
  $scope.$watch('model.modal', function(val) {
    $scope.show = val == MODAL.welcome;
  });
}

function AuthorizeCtrl(dev, $scope, $http, modelSrvc, apiSrvc, logFactory, MODAL, STATUS_GTALK, EXTERNAL_URL, googOauthUrl, $window) {
  var log = logFactory('AuthorizeCtrl'),
      model = modelSrvc.model;

  $scope.show = false;
  $scope.$watch('model.modal', function(val) {
    $scope.show = val == MODAL.authorize;
  });

  $scope.doOauth = function() {
    var url = modelSrvc.get('version.current.api.mock') ?
              EXTERNAL_URL.fakeOauth : googOauthUrl;
    $window.open(url);
  };
}

function GtalkUnreachableCtrl($scope, apiSrvc, $http, logFactory, MODAL) {
  var log = logFactory('GtalkUnreachableCtrl');
  $scope.show = false;
  $scope.$watch('model.modal', function(val) {
    $scope.show = val == MODAL.gtalkUnreachable;
  });
}

function NotInvitedCtrl($scope, apiSrvc, $http, logFactory, MODAL) {
  var log = logFactory('NotInvitedCtrl');
  $scope.show = false;
  $scope.$watch('model.modal', function(val) {
    $scope.show = val == MODAL.notInvited;
  });
}

function RequestInviteCtrl($scope, apiSrvc, $http, logFactory, MODAL) {
  var log = logFactory('RequestInviteCtrl');
  $scope.show = false;
  $scope.$watch('model.modal', function(val) {
    $scope.show = val == MODAL.requestInvite;
  });

  $scope.sendToLanternDevs = false;
  $scope.disableForm = false;
  $scope.submitButtonLabelKey = 'SEND_REQUEST';

  function resetForm() {
    $scope.disableForm = false;
    $scope.submitButtonLabelKey = 'SEND_REQUEST';
  }

  $scope.requestInvite = function() {
    $scope.disableForm = true;
    $scope.requestError = false;
    $scope.submitButtonLabelKey = 'SENDING_REQUEST';
    var params = {lanternDevs: $scope.sendToLanternDevs};
    $http.post(apiSrvc.urlfor('requestInvite', params))
      .success(function(data, status, headers, config) {
        log.debug('sent invite request');
        resetForm();
      })
      .error(function(data, status, headers, config) {
        log.debug('send invite request failed');
        $scope.requestError = true;
        resetForm();
      });
  };
}

function RequestSentCtrl($scope, apiSrvc, $http, logFactory, MODAL) {
  var log = logFactory('RequestSentCtrl');
  $scope.show = false;
  $scope.$watch('model.modal', function(val) {
    $scope.show = val == MODAL.requestSent;
  });
}

function FirstInviteReceivedCtrl($scope, apiSrvc, $http, logFactory, MODAL) {
  var log = logFactory('FirstInviteReceivedCtrl');
  $scope.show = false;
  $scope.$watch('model.modal', function(val) {
    $scope.show = val == MODAL.firstInviteReceived;
  });
}

function SystemProxyCtrl($scope, $http, apiSrvc, logFactory, MODAL, SETTING, INTERACTION) {
  var log = logFactory('SystemProxyCtrl');

  $scope.show = false;
  $scope.$watch('model.modal', function(val) {
    $scope.show = val == MODAL.systemProxy;
  });

  $scope.systemProxy = true;
  $scope.disableForm = false;
  $scope.submitButtonLabelKey = 'CONTINUE';

  function resetForm() {
    $scope.disableForm = false;
    $scope.submitButtonLabelKey = 'CONTINUE';
  }

  $scope.continue = function() {
    $scope.sysproxyError = false;
    $scope.disableForm = true;
    $scope.submitButtonLabelKey = 'CONFIGURING';
    var params = {systemProxy: $scope.systemProxy};
    $scope.interaction(INTERACTION.continue, params);
    resetForm(); // XXX pass in a callback to be called when $scope.interaction(..) completes
    /*
    $http.post(apiSrvc.urlfor('settings/', params))
      .success(function(data, status, headers, config) {
        log.debug('set systemProxy to', $scope.systemProxy);
        resetForm();
      })
      .error(function(data, status, headers, config) {
        log.debug('set systemProxy failed');
        $scope.sysproxyError = true;
        resetForm();
      });
    */
  };
}

function FinishedCtrl($scope, MODAL) {
  $scope.show = false;
  $scope.$watch('model.modal', function(val) {
    $scope.show = val == MODAL.finished;
  });
}

function VisCtrl($scope, logFactory) {
  var log = logFactory('VisCtrl');
  startVis();
}

function ContactDevsCtrl($scope, MODAL) {
  $scope.show = false;
  $scope.$watch('model.modal', function(val) {
    $scope.show = val == MODAL.contactDevs;
  });
}

function SettingsCtrl($scope, modelSrvc, logFactory, MODAL) {
  var log = logFactory('SettingsCtrl');

  $scope.show = false;
  $scope.$watch('model.modal', function(val) {
    $scope.show = val == MODAL.settings;
  });

  $scope.$watch('model.settings.autoStart', function(val) {
    $scope.autoStart = val;
  });

  $scope.$watch('model.settings.systemProxy', function(val) {
    $scope.systemProxy = val;
  });

  /*
  $scope.$watch('model.system.lang', function(val, oldVal) {
    if (val && !$scope._lang)
      $scope._lang = modelSrvc.get('settings.lang') || val;
  });

  $scope.$watch('model.settings.lang', function(val, oldVal) {
    if (val) $scope._lang = val;
  });
  */

  $scope.$watch('model.settings.autoReport', function(val) {
    $scope.autoReport = val;
  });
}

function ProxiedSitesCtrl($scope, logFactory, MODAL, SETTING) {
  $scope.show = false;
  $scope.$watch('model.modal', function(val) {
    $scope.show = val == MODAL.proxiedSites;
  });
  $scope.$watch('model.settings.proxiedSites', function(val) {
    if (val) $scope.proxiedSites = val.join('\n');
  });
  $scope.handleChange = function() {
    // XXX hook up to validator, only call when valid
    $scope.changeSetting(SETTING.proxiedSites,
      $scope.proxiedSites.split('\n'));
  };
}

function InviteFriendsCtrl($scope, modelSrvc, logFactory, MODE, MODAL) {
  var log = logFactory('InviteFriendsCtrl');

  $scope.show = false;
  $scope.$watch('model.modal', function(val) {
    $scope.show = val == MODAL.inviteFriends;
  });

  // XXX can default to true if only trusted contacts can see
  $scope.advertiseLantern = true;
  /*
  $scope.$watch('model.settings.mode', function(val) {
    if (val) $scope.advertiseLanternDefault = val == MODE.give;
  });
  $scope.$watch('advertiseLanternDefault', function(val) {
    var configuredVal = modelSrvc.get('settings.advertiseLantern');
    $scope.advertiseLantern = typeof configuredVal == 'undefined' ?
      $scope.advertiseLanternDefault : configuredVal;
  });
  */
}

function AuthorizeLaterCtrl($scope, logFactory, MODAL) {
  $scope.show = false;
  $scope.$watch('model.modal', function(val) {
    $scope.show = val == MODAL.authorizeLater;
  });
}

function AboutCtrl($scope, logFactory, MODAL) {
  $scope.show = false;
  $scope.$watch('model.modal', function(val) {
    $scope.show = val == MODAL.about;
  });
}

function UpdateAvailableCtrl($scope, logFactory, MODAL) {
  $scope.show = false;
  $scope.$watch('model.modal', function(val) {
    $scope.show = val == MODAL.updateAvailable;
  });
}

function ConfirmResetCtrl($scope, logFactory, MODAL) {
  $scope.show = false;
  $scope.$watch('model.modal', function(val) {
    $scope.show = val == MODAL.confirmReset;
  });
}

function GiveModeForbiddenCtrl($scope, logFactory, MODAL) {
  $scope.show = false;
  $scope.$watch('model.modal', function(val) {
    $scope.show = val == MODAL.giveModeForbidden;
  });
}

function DevCtrl($scope, dev, logFactory, MODEL_SYNC_CHANNEL, cometdSrvc, modelSrvc) {
  var log = logFactory('DevCtrl'),
      model = modelSrvc.model;

  $scope.$watch('model', function() {
    if (typeof 'model' != 'undefined' && dev.value) {
      $scope.editableModel = angular.toJson(model, true);
    }
  }, true);

  $scope.handleUpdate = function() {
    cometdSrvc.batch(function() {
      syncObject('', angular.fromJson($scope.editableModel), model);
    });
  };

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
        // propagate local model changes to other clients
        cometdSrvc.publish(MODEL_SYNC_CHANNEL, {path: path, value: src[name]});
        dst[name] = angular.copy(src[name]);
      }
    }
  }
}
