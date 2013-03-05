'use strict';

// XXX have modal controllers inherit from a base class to be more DRY?

// XXX use data-loading-text instead of submitButtonLabelKey below?
// see http://twitter.github.com/bootstrap/javascript.html#buttons

function RootCtrl(dev, sanity, $scope, logFactory, modelSrvc, cometdSrvc, langSrvc, LANG, apiSrvc, DEFAULT_AVATAR_URL, ENUMS, EXTERNAL_URL, VER, $window) {
  var log = logFactory('RootCtrl'),
      model = $scope.model = modelSrvc.model,
      MODE = ENUMS.MODE,
      CONNECTIVITY = ENUMS.CONNECTIVITY;
  $scope.modelSrvc = modelSrvc;
  $scope.cometdSrvc = cometdSrvc;
  $scope.versionFrontend = VER.join('.');
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

  $scope.$on('cometdConnected', function() {
    log.debug('cometdConnected');
    $scope.cometdConnected = true;
    $scope.$apply();
  });

  $scope.$on('cometdDisconnected', function () {
    log.debug('cometdDisconnected');
    $scope.cometdConnected = false;
    $scope.$apply();
  });

  $scope.$watch('model.settings.mode', function(mode) {
    $scope.inGiveMode = mode == MODE.give;
    $scope.inGetMode = mode == MODE.get;
  }, true);

  $scope.$watch('model.mock', function(mock) {
    $scope.mockBackend = !!mock;
  }, true);


  $scope.$watch('model.location.country', function(country) {
    if (country && model.countries[country])
      $scope.inCensoringCountry = model.countries[country].censors;
  }, true);

  $scope.$watch('model.connectivity.gtalk', function(gtalk) {
    $scope.gtalkNotConnected = gtalk == CONNECTIVITY.notConnected;
    $scope.gtalkConnecting = gtalk == CONNECTIVITY.connecting;
    $scope.gtalkConnected = gtalk == CONNECTIVITY.connected;
  }, true);

  $scope.notifyLanternDevs = true;

  $scope.refresh = function() {
    location.reload(true); // true to bypass cache and force request to server
  };

  $scope.interaction = function(interactionid, extra) {
    return apiSrvc.interaction(interactionid, extra)
      .success(function(data, status, headers, config) {
        log.debug('interaction(', interactionid, extra || '', ') successful');
      })
      // XXX sub-controllers need to hook into this
      .error(function(data, status, headers, config) {
        log.error('interaction(', interactionid, extra, ') failed');
      });
  };

  $scope.changeSetting = function(key, val) {
    var update = {path: '/settings/'+key, value: val};
    return $scope.interaction(INTERACTION.set, update);
  };
}

function SanityCtrl($scope, sanity, modelSrvc, cometdSrvc, MODAL, REQUIRED_API_VER, logFactory) {
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
  }, true);

  $scope.$watch('model.version.installed.api', function(installed) {
    if (angular.isUndefined(installed)) return;
    for (var key in {major: 'major', minor: 'minor'}) {
      if (installed[key] != REQUIRED_API_VER[key]) {
        sanity.value = false;
        log.error('Backend api version', installed,
         'incompatible with required version', REQUIRED_API_VER);
         return;
      }
    }
  }, true);
}

function RequestInviteCtrl($scope, logFactory, MODAL, INTERACTION) {
  var log = logFactory('RequestInviteCtrl');

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

function SystemProxyCtrl($scope, logFactory, MODAL, SETTING, INTERACTION) {
  var log = logFactory('SystemProxyCtrl');

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
    $scope.interaction(INTERACTION.continue, $scope.systemProxy).then(resetForm);
  };
}

function ContactCtrl($scope, MODAL, $filter, CONTACT_FORM_MAXLEN) {
  $scope.CONTACT_FORM_MAXLEN = CONTACT_FORM_MAXLEN;

  $scope.show = false;
  $scope.$watch('model.modal', function(modal) {
    $scope.show = modal == MODAL.contact;
    if ($scope.show) {
      var reportedState = $filter('json')($filter('reportedState')($scope.model));
      $scope.message = $filter('i18n')('MESSAGE_PLACEHOLDER') + reportedState;
      $scope.contactForm.contactMsg.$pristine = true;
    }
  }, true);
}

function SettingsCtrl($scope, $timeout, modelSrvc, logFactory, MODAL) {
  var log = logFactory('SettingsCtrl');

  $scope.$watch('model.settings.runAtSystemStart', function(runAtSystemStart) {
    $scope.runAtSystemStart = runAtSystemStart;
  }, true);

  $scope.$watch('model.settings.autoReport', function(autoReport) {
    $scope.autoReport = autoReport;
  }, true);

  $scope.$watch('model.settings.systemProxy', function(systemProxy) {
    $scope.systemProxy = systemProxy;
  }, true);

  $scope.$watch('model.settings.proxyAllSites', function(proxyAllSites) {
    $scope.proxyAllSites = proxyAllSites;
  }, true);
}

function ProxiedSitesCtrl($scope, $timeout, logFactory, MODAL, SETTING, INTERACTION, INPUT_PAT) {
  var log = logFactory('ProxiedSitesCtrl'),
      DOMAIN = INPUT_PAT.DOMAIN,
      IPV4 = INPUT_PAT.IPV4,
      nproxiedSitesMax = 1000,
      original,
      normalized;

  function updateComplete() {
    $scope.updating = false;
    $scope.submitButtonLabelKey = 'CONTINUE';
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
  }, true);
  $scope.$watch('model.nproxiedSitesMax', function(nproxiedSitesMax_) {
    nproxiedSitesMax = nproxiedSitesMax_;
    if ($scope.input)
      $scope.validate($scope.input);
  }, true);

  function normalize(domainOrIP) {
    return angular.lowercase(domainOrIP.trim());
  }

  $scope.validate = function(value) {
    if (!value || !value.length) {
      $scope.errorLabelKey = 'ERROR_ONE_REQUIRED';
      $scope.errorCause = '';
      return false;
    }
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

  $scope.handleReset = function() {
    $scope.input = original.join('\n');
    makeValid();
  };

  $scope.handleContinue = function() {
    if ($scope.proxiedSitesForm.$invalid) {
      log.debug('invalid input, not sending update');
      return $scope.interaction(INTERACTION.continue);
    }
    if (_.isEqual(original, normalized)) {
      log.debug('input matches original, not sending update');
      return $scope.interaction(INTERACTION.continue);
    }
    log.debug('sending update');
    $scope.input = normalized.join('\n');
    $scope.updating = true;
    $scope.submitButtonLabelKey = 'UPDATING';
    $scope.changeSetting(SETTING.proxiedSites, normalized).then(function() {
      updateComplete();
      log.debug('update complete, sending continue');
      $scope.interaction(INTERACTION.continue);
    });
  };
}

function LanternFriendsCtrl($scope, modelSrvc, logFactory, MODE, MODAL, $filter, INPUT_PAT, INTERACTION) {
  var log = logFactory('LanternFriendsCtrl'),
      model = modelSrvc.model,
      EMAIL = INPUT_PAT.EMAIL;

  $scope.invitees = [];

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
  }, true);

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
      return {id: i.email, text: $filter('prettyUser')(i)};
    }), $scope.selectInvitees.tags);
  }

  $scope.$watch('model.roster', function(roster) {
    if (!roster) return;
    updateCompletions();
  }, true);

  $scope.selectInvitees = {
    tags: [],
    tokenSeparators: [',', ' '],
    multiple: true,
  //selectOnBlur: true, // requires select2 3.3
    maximumSelectionSize: function() {
      return model.ninvites || 0;
    },
    formatSelection: function(item) {
      return item.id;
    },
    formatSearching: function() {
      return $filter('i18n')('SEARCHING_ELLIPSIS');
    },
    formatSelectionTooBig: function(max) {
      return $filter('i18n')('NINVITES_REACHED', max);
    },
    formatNoMatches: function() {
      return $filter('i18n')('ENTER_VALID_EMAIL');
    },
    createSearchChoice: function(input) {
      return EMAIL.test(input) ? {id: input, text: input} : undefined;
    }
  };

  function resetForm() {
    $scope.invitees = [];
  }

  $scope.valid = function() {
    var invitees = $scope.invitees;
    if (!invitees) return true;
    if (!('length' in invitees)) return false;
    if (invitees.length > model.ninvites) return false;
    for (var i=0, ii=invitees[i]; ii; ii=invitees[++i]) {
      if (!EMAIL.test(ii.id)) return false;
    }
    return true;
  };

  $scope.invite = function() {
    if ($scope.invitees.length) {
      var data = _.map($scope.invitees, function(i) { return i.id });
      $scope.interaction(INTERACTION.invite, data).then(resetForm);
    }
  };
}

function ScenariosCtrl($scope, $timeout, logFactory, modelSrvc, dev, MODAL, INTERACTION) {
  var log = logFactory('ScenariosCtrl'),
      model = modelSrvc.model;

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
  }, true);

  $scope.submit = function() {
    var appliedScenarios = {};
    for (var i=0, ii=$scope.appliedScenarios[i]; ii; ii=$scope.appliedScenarios[++i]) {
      var group_key_pair = ii.split('.');
      appliedScenarios[group_key_pair[0]] = group_key_pair[1];
    }
    $scope.interaction(INTERACTION.continue, {path: 'mock.scenarios.applied', value: appliedScenarios});
  };
}
