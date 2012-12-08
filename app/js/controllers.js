'use strict';

// XXX have modal controllers inherit from a base class to be more DRY?

// XXX use data-loading-text instead of submitButtonLabelKey below?
// see http://twitter.github.com/bootstrap/javascript.html#buttons

function RootCtrl(dev, sanity, $scope, logFactory, modelSrvc, cometdSrvc, langSrvc, $http, apiSrvc, DEFAULT_AVATAR_URL, ENUMS, $window) {
  var log = logFactory('RootCtrl'),
      model = $scope.model = modelSrvc.model,
      MODE = ENUMS.MODE,
      CONNECTIVITY = ENUMS.CONNECTIVITY,
      EXTERNAL_URL = ENUMS.EXTERNAL_URL;
  $scope.modelSrvc = modelSrvc;
  $scope.cometdSrvc = cometdSrvc;
  $scope.dev = dev;
  if (dev.value) {
    $window.model = model; // easier interactive debugging
  }
  $scope.DEFAULT_AVATAR_URL = DEFAULT_AVATAR_URL;
  angular.forEach(ENUMS, function(val, key) {
    $scope[key] = val;
  });

  // XXX better place for these?
  $scope.lang = langSrvc.lang;
  $scope.direction = langSrvc.direction;

  $scope.$watch('model.settings.mode', function(mode) {
    $scope.inGiveMode = mode == MODE.give;
    $scope.inGetMode = mode == MODE.get;
  });

  $scope.$watch('model.mock', function(mock) {
    $scope.mockBackend = !!mock;
  });


  $scope.$watch('model.location.country', function(country) {
    if (country)
      $scope.inCensoringCountry = model.countries[country].censors;
  });

  $scope.$watch('model.connectivity.gtalk', function(gtalk) {
    $scope.gtalkNotConnected = gtalk == CONNECTIVITY.notConnected;
    $scope.gtalkConnecting = gtalk == CONNECTIVITY.connecting;
    $scope.gtalkConnected = gtalk == CONNECTIVITY.connected;
  });

  $scope.notifyLanternDevs = true;
  $scope.$watch('model.settings.autoReport', function(autoReport) {
    if (angular.isDefined(autoReport))
      $scope.notifyLanternDevs = autoReport;
  });
  $scope.maybeNotify = function() {
    // XXX TODO
    if ($scope.notifyLanternDevs) {
      log.warn('Notify Lantern developers not yet implemented');
    }
  };

  $scope.refresh = function() {
    location.reload(true); // true to bypass cache and force request to server
  };

  $scope.doOauth = function() {
    $window.open(model.connectivity.gtalkOauthUrl);
  };

  $scope.interaction = function(interaction, extra) {
    var params = angular.extend({interaction: interaction}, extra || {});
    return $http.post(apiSrvc.urlfor('interaction', params))
      .success(function(data, status, headers, config) {
        log.debug('interaction', interaction, 'successful');
      })
      .error(function(data, status, headers, config) {
        log.debug('interaction', interaction, 'failed'); // XXX
      });
  };

  $scope.updateState = function(updates) {
    updates = angular.toJson(updates);
    return $http.post(apiSrvc.urlfor('state', {updates: updates}))
      .success(function(data, status, headers, config) {
        log.debug('Update state successful', updates);
      })
      .error(function(data, status, headers, config) {
        log.debug('Update state failed', updates);
      });
  };

  $scope.changeSetting = function(key, val) {
    var updates = {};
    updates['settings.'+key] = val;
    return $scope.updateState(updates);
  }
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

function SanityCtrl($scope, sanity, modelSrvc, cometdSrvc, MODAL, REQUIRED_VERSIONS, logFactory) {
  var log = logFactory('SanityCtrl');
  $scope.sanity = sanity;

  $scope.show = false;
  $scope.$watch('sanity.value', function(sane) {
    if (!sane) {
      log.warn('sanity false, disconnecting');
      modelSrvc.disconnect();
      modelSrvc.model.modal = MODAL.none;
      $scope.show = true;
    }
  });

  $scope.$watch('model.version.installed', function(installed) {
    if (angular.isUndefined(installed)) return;
    for (var module in REQUIRED_VERSIONS) {
      for (var key in {major: 'major', minor: 'minor'}) {
        if (installed[module][key] != REQUIRED_VERSIONS[module][key]) {
          sanity.value = false;
          log.error('Available version of', moduleName, installed[moduleName],
           'incompatible with required version', requiredVer);
           return;
        }
      }
    }
  }, true);
}

function SettingsLoadFailureCtrl($scope, MODAL) {
  $scope.show = false;
  $scope.$watch('model.modal', function(modal) {
    $scope.show = modal == MODAL.settingsLoadFailure;
  });
}

function WelcomeCtrl($scope, modelSrvc, logFactory, MODAL) {
  var log = logFactory('WelcomeCtrl'),
      model = $scope.model = modelSrvc.model;
  $scope.show = false;
  $scope.$watch('model.modal', function(modal) {
    $scope.show = modal == MODAL.welcome;
  });
}

function AuthorizeCtrl($scope, logFactory, MODAL) {
  var log = logFactory('AuthorizeCtrl');

  $scope.show = false;
  $scope.$watch('model.modal', function(modal) {
    $scope.show = modal == MODAL.authorize;
  });
}

function GtalkConnectingCtrl($scope, logFactory, MODAL) {
  var log = logFactory('GtalkConnectingCtrl');
  $scope.show = false;
  $scope.$watch('model.modal', function(modal) {
    $scope.show = modal == MODAL.gtalkConnecting;
  });
}

function GtalkUnreachableCtrl($scope, apiSrvc, $http, logFactory, MODAL) {
  var log = logFactory('GtalkUnreachableCtrl');
  $scope.show = false;
  $scope.$watch('model.modal', function(modal) {
    $scope.show = modal == MODAL.gtalkUnreachable;
  });
}

function NotInvitedCtrl($scope, apiSrvc, $http, logFactory, MODAL) {
  var log = logFactory('NotInvitedCtrl');
  $scope.show = false;
  $scope.$watch('model.modal', function(modal) {
    $scope.show = modal == MODAL.notInvited;
  });
}

function RequestInviteCtrl($scope, apiSrvc, $http, logFactory, MODAL) {
  var log = logFactory('RequestInviteCtrl');
  $scope.show = false;
  $scope.$watch('model.modal', function(modal) {
    $scope.show = modal == MODAL.requestInvite;
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
  $scope.$watch('model.modal', function(modal) {
    $scope.show = modal == MODAL.requestSent;
  });
}

function FirstInviteReceivedCtrl($scope, apiSrvc, $http, logFactory, MODAL) {
  var log = logFactory('FirstInviteReceivedCtrl');
  $scope.show = false;
  $scope.$watch('model.modal', function(modal) {
    $scope.show = modal == MODAL.firstInviteReceived;
  });
}

function SystemProxyCtrl($scope, $http, apiSrvc, logFactory, MODAL, SETTING, INTERACTION) {
  var log = logFactory('SystemProxyCtrl');

  $scope.show = false;
  $scope.$watch('model.modal', function(modal) {
    $scope.show = modal == MODAL.systemProxy;
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
  $scope.$watch('model.modal', function(modal) {
    $scope.show = modal == MODAL.finished;
  });
}

function ContactDevsCtrl($scope, MODAL) {
  $scope.show = false;
  $scope.$watch('model.modal', function(modal) {
    $scope.show = modal == MODAL.contactDevs;
  });
}

function SettingsCtrl($scope, modelSrvc, logFactory, MODAL) {
  var log = logFactory('SettingsCtrl');

  $scope.show = false;
  $scope.$watch('model.modal', function(modal) {
    $scope.show = modal == MODAL.settings;
  });

  $scope.$watch('model.settings.autoStart', function(autoStart) {
    $scope.autoStart = autoStart;
  });

  $scope.$watch('model.settings.systemProxy', function(systemProxy) {
    $scope.systemProxy = systemProxy;
  });

  $scope.$watch('model.settings.autoReport', function(autoReport) {
    $scope.autoReport = autoReport;
  });
}

function ProxiedSitesCtrl($scope, $timeout, logFactory, MODAL, SETTING, INTERACTION, INPUT_PATS) {
  var log = logFactory('ProxiedSitesCtrl'),
      DOMAIN = INPUT_PATS.DOMAIN,
      IPV4 = INPUT_PATS.IPV4,
      DELAY = 1000, // milliseconds
      nproxiedSitesMax = 1000, // default value, should be overwritten below
      sendUpdatePromise,
      original,
      normalized;

  $scope.show = false;
  $scope.$watch('model.modal', function(modal) {
    $scope.show = modal == MODAL.proxiedSites;
  });

  $scope.updating = false;
  $scope.$watch('updating', function(updating) {
    $scope.submitButtonLabelKey = updating ? 'UPDATING' : 'CONTINUE';
  });

  function updateComplete() {
    $scope.updating = false;
    $scope.dirty = false;
  }

  function makeValid() {
    $scope.errorLabelKey = '';
    $scope.errorCause = '';
    $scope.proxiedSitesForm.input.$setValidity('generic', true);
  }

  $scope.$watch('model.settings.proxiedSites', function(proxiedSites) {
    if (proxiedSites) {
      original = proxiedSites;
      $scope.input = proxiedSites.join('\n');
      updateComplete();
      makeValid();
    }
  });
  $scope.$watch('model.nproxiedSitesMax', function(nproxiedSitesMax_) {
    nproxiedSitesMax = nproxiedSitesMax_;
    if ($scope.input)
      $scope.validate($scope.input);
  });

  function normalize(domainOrIP) {
    return angular.lowercase(domainOrIP.trim());
  }

  $scope.validate = function(value) {
    if (angular.isUndefined(value)) return;
    if (angular.isString(value)) value = value.split('\n');
    normalized = [];
    var uniq = {};
    $scope.errorLabelKey = '';
    $scope.errorCause = '';
    for (var i=0, line=value[i], l=value.length, normline;
         i<l && !$scope.errorLabelKey;
         line=value[++i]) {
      normline = normalize(line);
      if (!normline) continue;
      if (!(DOMAIN.test(normline) ||
            IPV4.test(normline))) {
        $scope.errorLabelKey = 'ERROR_INVALID_LINE';
        $scope.errorCause = line;
      } else if (!(normline in uniq)) {
        normalized.push(normline);
        uniq[normline] = true;
      }
    }
    if (normalized.length > nproxiedSitesMax) {
      $scope.errorLabelKey = 'ERROR_MAX_PROXIED_SITES_EXCEEDED';
      $scope.errorCause = '';
    }
    return !$scope.errorLabelKey;
  };

  $scope.reset = function() {
    $scope.updating = true;
    $scope.interaction(INTERACTION.reset).then(updateComplete);
    makeValid();
  };

  $scope.handleUpdate = function() {
    $scope.dirty = true;
    if (sendUpdatePromise) {
      $timeout.cancel(sendUpdatePromise);
    }
    sendUpdatePromise = $timeout(function() {
      sendUpdatePromise = null;
      if ($scope.proxiedSitesForm.$invalid) {
        log.debug('invalid input, not sending update');
        return;
      }
      $scope.input = normalized.join('\n');
      if (angular.equals(original, normalized)) { // order ignored
        log.debug('input matches original, not sending update');
        updateComplete();
        return;
      }
      $scope.updating = true;
      $scope.changeSetting(SETTING.proxiedSites, normalized).then(updateComplete);
    }, DELAY);
  };
}

function LanternFriendsCtrl($scope, modelSrvc, logFactory, MODE, MODAL) {
  var log = logFactory('LanternFriendsCtrl'),
      model = modelSrvc.model;

  $scope.show = false;
  $scope.$watch('model.modal', function(modal) {
    $scope.show = modal == MODAL.lanternFriends;
  });
}

function AuthorizeLaterCtrl($scope, logFactory, MODAL) {
  $scope.show = false;
  $scope.$watch('model.modal', function(modal) {
    $scope.show = modal == MODAL.authorizeLater;
  });
}

function AboutCtrl($scope, logFactory, MODAL, VER) {
  $scope.versionFrontend = VER.join('.');
  $scope.show = false;
  $scope.$watch('model.modal', function(modal) {
    $scope.show = modal == MODAL.about;
  });
}

function UpdateAvailableCtrl($scope, logFactory, MODAL) {
  $scope.show = false;
  $scope.$watch('model.modal', function(modal) {
    $scope.show = modal == MODAL.updateAvailable;
  });
}

function ConfirmResetCtrl($scope, logFactory, MODAL) {
  $scope.show = false;
  $scope.$watch('model.modal', function(modal) {
    $scope.show = modal == MODAL.confirmReset;
  });
}

function GiveModeForbiddenCtrl($scope, logFactory, MODAL) {
  $scope.show = false;
  $scope.$watch('model.modal', function(modal) {
    $scope.show = modal == MODAL.giveModeForbidden;
  });
}

function ScenariosCtrl($scope, $timeout, apiSrvc, logFactory, modelSrvc, dev, MODAL, INTERACTION) {
  var log = logFactory('ScenariosCtrl'),
      model = modelSrvc.model;

  $scope.show = false;
  $scope.$watch('model.modal', function(modal) {
    $scope.show = modal == MODAL.scenarios;
  });

  $scope.$watch('model.mock.scenarios.applied', function(applied) {
    if (applied) {
      $scope.appliedScenarios = [];
      // XXX ui-select2 timing issue
      $timeout(function() {
        for (var group in applied) {
          $scope.appliedScenarios.push(group+'.'+applied[group]);
        }
      });
    }
  });

  $scope.multiple = true; // XXX without this, ui-select2 with "multiple" attr causes an exception

  $scope.submit = function() {
    var appliedScenarios = {};
    for (var i=0, ii=$scope.appliedScenarios[i]; ii; ii=$scope.appliedScenarios[++i]) {
      var group_key_pair = ii.split('.');
      appliedScenarios[group_key_pair[0]] = group_key_pair[1];
    }
    appliedScenarios = angular.toJson(appliedScenarios);
    $scope.interaction(INTERACTION.continue, {appliedScenarios: appliedScenarios})
  };
}

function DevCtrl($scope, dev, logFactory, MODEL_SYNC_CHANNEL, cometdSrvc, modelSrvc) {
  var log = logFactory('DevCtrl'),
      model = modelSrvc.model;

  $scope.$watch('model', function() {
    if (angular.isDefined(model) && dev.value) {
      $scope.editableModel = angular.toJson(model, true);
    }
  }, true);

  function sanitized(obj) {
    if (!angular.isObject(obj)) {
      throw Error('object expected');
    }
    var san = angular.isArray(obj) ? [] : {};
    for (var key in obj) {
      var val = obj[key];
      if (key.charAt(0) != '$') {
        if (angular.isObject(val))
          san[key] = sanitized(val);
        else
          san[key] = val;
      }
    }
    return san;
  }

  $scope.handleUpdate = function() {
    log.debug('in handleUpdate');
    cometdSrvc.batch(function() {
      syncObject('', angular.fromJson($scope.editableModel), sanitized(model));
    });
  };

  function syncObject(parent, src, dst) {
    if (!_.isPlainObject(src) || !_.isPlainObject(dst)) {
      throw Error('src and dst must be objects');
    }

    if (_.isEqual(src, dst))
      return;

    // remove deleted fields
    for (var name in dst) {
      var path = (parent ? parent + '.' : '') + name;
      if (!(name in src)) {
        log.debug('publishing: path:', path, 'delete:', true);
        cometdSrvc.publish(MODEL_SYNC_CHANNEL, {path: path, delete: true});
        delete dst[name];
      }
    }

    // merge updated fields
    for (var name in src) {
      var path = (parent ? parent + '.' : '') + name;
      if (_.isEqual(src[name], dst[name])) {
        continue;
      }
      if (angular.isArray(src[name])) {
        log.debug('publishing: path:', path, 'value:', src[name]);
        cometdSrvc.publish(MODEL_SYNC_CHANNEL, {path: path, value: src[name]});
        dst[name] = src[name].slice();
      } else if (angular.isObject(src[name])) {
        if (!angular.isObject(dst[name])) {
          log.debug('publishing: path:', path, 'delete:', true);
          cometdSrvc.publish(MODEL_SYNC_CHANNEL, {path: path, delete: true});
          dst[name] = {};
        }
        syncObject(path, src[name], dst[name]);
      } else {
        log.debug('publishing: path:', path, 'value:', src[name]);
        cometdSrvc.publish(MODEL_SYNC_CHANNEL, {path: path, value: src[name]});
        dst[name] = src[name];
      }
    }
  }
}
