'use strict';

// XXX have modal controllers inherit from a base class to be more DRY?

// XXX use data-loading-text instead of submitButtonLabelKey below?
// see http://twitter.github.com/bootstrap/javascript.html#buttons

function RootCtrl(dev, sanity, $scope, logFactory, modelSrvc, cometdSrvc, langSrvc, LANG, apiSrvc, DEFAULT_AVATAR_URL, ENUMS, EXTERNAL_URL, $window) {
  var log = logFactory('RootCtrl'),
      model = $scope.model = modelSrvc.model,
      MODE = ENUMS.MODE,
      CONNECTIVITY = ENUMS.CONNECTIVITY;
  $scope.modelSrvc = modelSrvc;
  $scope.cometdSrvc = cometdSrvc;
  $scope.dev = dev;
  if (dev.value) {
    $window.model = model; // easier interactive debugging
  }
  $scope.DEFAULT_AVATAR_URL = DEFAULT_AVATAR_URL;
  $scope.EXTERNAL_URL = EXTERNAL_URL;
  angular.forEach(ENUMS, function(val, key) {
    $scope[key] = val;
  });

  $scope.lang = langSrvc.lang;
  $scope.direction = langSrvc.direction;
  $scope.LANG = LANG;

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

  $scope.refresh = function() {
    location.reload(true); // true to bypass cache and force request to server
  };

  $scope.interaction = function(interactionid, extra) {
    return apiSrvc.interaction(interactionid, extra)
      .success(function(data, status, headers, config) {
        log.debug('interaction(', interactionid, extra || '', ') successful');
      })
      .error(function(data, status, headers, config) {
        log.error('interaction(', interactionid, extra, ') failed');
      });
  };

  $scope.changeSetting = function(key, val) {
    var update = {path: 'settings.'+key, value: val};
    return $scope.interaction(INTERACTION.set, update);
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

function GtalkUnreachableCtrl($scope, logFactory, MODAL) {
  var log = logFactory('GtalkUnreachableCtrl');
  $scope.show = false;
  $scope.$watch('model.modal', function(modal) {
    $scope.show = modal == MODAL.gtalkUnreachable;
  });
}

function NotInvitedCtrl($scope, logFactory, MODAL) {
  var log = logFactory('NotInvitedCtrl');
  $scope.show = false;
  $scope.$watch('model.modal', function(modal) {
    $scope.show = modal == MODAL.notInvited;
  });
}

function RequestInviteCtrl($scope, logFactory, MODAL, INTERACTION) {
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
    return $scope.interaction(INTERACTION.requestInvite, params) // XXX TODO
      .error(function() { $scope.requestError = true; })
      .then(resetForm);
  };
}

function RequestSentCtrl($scope, logFactory, MODAL) {
  var log = logFactory('RequestSentCtrl');
  $scope.show = false;
  $scope.$watch('model.modal', function(modal) {
    $scope.show = modal == MODAL.requestSent;
  });
}

function FirstInviteReceivedCtrl($scope, logFactory, MODAL) {
  var log = logFactory('FirstInviteReceivedCtrl');
  $scope.show = false;
  $scope.$watch('model.modal', function(modal) {
    $scope.show = modal == MODAL.firstInviteReceived;
  });
}

function SystemProxyCtrl($scope, logFactory, MODAL, SETTING, INTERACTION) {
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
    var p = {path: 'settings.'+SETTING.systemProxy, value: $scope.systemProxy};
    $scope.interaction(INTERACTION.continue, p).then(resetForm);
  };
}

function FinishedCtrl($scope, MODAL) {
  $scope.show = false;
  $scope.$watch('model.modal', function(modal) {
    $scope.show = modal == MODAL.finished;
  });
  $scope.autoReport = true;
}

function ContactCtrl($scope, MODAL) {
  $scope.show = false;
  $scope.$watch('model.modal', function(modal) {
    $scope.show = modal == MODAL.contact;
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

function ProxiedSitesCtrl($scope, $timeout, logFactory, MODAL, SETTING, INTERACTION, INPUT_PAT) {
  var log = logFactory('ProxiedSitesCtrl'),
      DOMAIN = INPUT_PAT.DOMAIN,
      IPV4 = INPUT_PAT.IPV4,
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
      if (_.isEqual(original, normalized)) {
        log.debug('input matches original, not sending update');
        updateComplete();
        return;
      }
      $scope.updating = true;
      $scope.changeSetting(SETTING.proxiedSites, normalized).then(updateComplete);
    }, DELAY);
  };
}

function LanternFriendsCtrl($scope, modelSrvc, logFactory, MODE, MODAL, $filter, INPUT_PAT, INTERACTION) {
  var log = logFactory('LanternFriendsCtrl'),
      model = modelSrvc.model,
      EMAIL = INPUT_PAT.EMAIL;

  $scope.show = false;
  $scope.$watch('model.modal', function(modal) {
    $scope.show = modal == MODAL.lanternFriends;
  });

  $scope.invitees = [];
  $scope.validateInvitees = function(invitees) {
    if (invitees.length > getByPath(model, 'ninvites', 0))
      return false;
    for (var i=0, ii=invitees[i]; ii; ii=invitees[++i]) {
      if (!EMAIL.test(ii.id))
        return false;
    }
    return true;
  }

  var sortedFriendEmails = [];
  $scope.$watch('model.friends', function(friends) {
    if (!friends) return;
    friends = _.flatten([friends.current, friends.pending], true);
    sortedFriendEmails = [];
    for (var i=0, ii=friends[i]; ii; ii=friends[++i]) {
      ii.email && sortedFriendEmails.push(ii.email);
    }
    sortedFriendEmails.sort();
    updateCompletions();
  });

  function updateCompletions() {
    var roster = model.roster;
    if (!roster) return;
    var notAlreadyFriends;
    if (_.isEmpty(sortedFriendEmails)) {
      notAlreadyFriends = roster;
    } else {
      notAlreadyFriends = [];
      for (var i=0, ii=roster[i]; ii; ii=roster[++i]) {
        if (_.indexOf(sortedFriendEmails, ii.email, true) == -1)
          notAlreadyFriends.push(ii);
      }
    }
    $scope.notAlreadyFriends = notAlreadyFriends;
    angular.copy(_.map(notAlreadyFriends, function(i) {
      return {id: i.email, text: i.name + ' (' + i.email + ')'};
    }), $scope.selectInvitees.tags);
  }

  $scope.$watch('model.roster', function(roster) {
    if (!roster) return;
    updateCompletions();
  });

  $scope.$watch('model.ninvites', function(ninvites) {
    if (angular.isDefined(ninvites))
      $scope.selectInvitees.maximumSelectionSize = ninvites; // XXX https://github.com/ivaynberg/select2/issues/648
  });

  $scope.selectInvitees = {
    tags: [],
    multiple: true,
    formatSelectionTooBig: function(max) {
      return $filter('i18n')('NINVITES_REACHED'); // XXX use max in this message
    },
    // XXX could use something like these if https://github.com/ivaynberg/select2/issues/647 is fixed:
    validateResult: function(item) {
      return EMAIL.test(item.id);
    },
    formatInvalidInput: function(item) {
      return $filter('i18n')('NOT_AN_EMAIL'); // XXX use item.id in this message
    }
  };

  function resetForm() {
    $scope.invitees = [];
  }

  $scope.continue = function() {
    var invitees = _.map($scope.invitees, function(i) { return i.id });
    return $scope.interaction(INTERACTION.continue, invitees)
      .success(function(data, status, headers, config) {
        // XXX display notification
        console.log('successfully invited', invitees);
        resetForm();
      })
      .error(function(data, status, headers, config) {
        // XXX display notification
        console.log('error inviting', invitees);
        resetForm();
      });
  };
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

function ScenariosCtrl($scope, $timeout, logFactory, modelSrvc, dev, MODAL, INTERACTION) {
  var log = logFactory('ScenariosCtrl'),
      model = modelSrvc.model;

  $scope.show = false;
  $scope.$watch('model.modal', function(modal) {
    $scope.show = modal == MODAL.scenarios;
  });

  $scope.$watch('model.mock.scenarios.applied', function(applied) {
    if (applied) {
      // XXX ui-select2 timing issue
      $timeout(function() {
        $scope.appliedScenarios = [];
        for (var group in applied) {
          $scope.appliedScenarios.push(group+'.'+applied[group]);
        }
      });
    }
  });

  $scope.submit = function() {
    var appliedScenarios = {};
    for (var i=0, ii=$scope.appliedScenarios[i]; ii; ii=$scope.appliedScenarios[++i]) {
      var group_key_pair = ii.split('.');
      appliedScenarios[group_key_pair[0]] = group_key_pair[1];
    }
    $scope.interaction(INTERACTION.continue, {path: 'mock.scenarios.applied', value: appliedScenarios});
  };
}

function DevCtrl($scope, dev, logFactory, MODEL_SYNC_CHANNEL, modelSrvc) {
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
    var updates = [];
    syncObject('', angular.fromJson($scope.editableModel), sanitized(model), updates);
    if (updates.length) {
      $scope.interaction(INTERACTION.developer, updates);
    }
  };

  function syncObject(parent, src, dst, updates) {
    if (!_.isPlainObject(src) || !_.isPlainObject(dst)) {
      throw Error('src and dst must be objects');
    }

    if (_.isEqual(src, dst))
      return;

    // remove deleted fields
    for (var name in dst) {
      var path = (parent ? parent + '.' : '') + name;
      if (!(name in src)) {
        updates.push({path: path, delete: true});
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
        updates.push({path: path, value: src[name]});
        dst[name] = src[name].slice();
      } else if (angular.isObject(src[name])) {
        if (!angular.isObject(dst[name])) {
          updates.push({path: path, delete: true});
          dst[name] = {};
        }
        syncObject(path, src[name], dst[name], updates);
      } else {
        updates.push({path: path, value: src[name]});
        dst[name] = src[name];
      }
    }
  }
}
