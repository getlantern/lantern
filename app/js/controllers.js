'use strict';

function RootCtrl() {
}

function SettingsLoadFailureCtrl($scope, MODAL) {
  $scope.show = false;
  $scope.$watch('model.modal', function (modal) {
    $scope.show = modal === MODAL.settingsLoadFailure;
  });
}

function SponsorCtrl($scope, MODAL) {
  $scope.show = false;
  $scope.$watch('model.modal', function (modal) {
    $scope.show = modal === MODAL.sponsor;
  });
}

function SponsorToContinueCtrl($scope, MODAL) {
  $scope.show = false;
  $scope.$watch('model.modal', function (modal) {
    $scope.show = modal === MODAL.sponsorToContinue;
  });
}

function UpdateAvailableCtrl($scope, MODAL) {
  $scope.show = false;
  $scope.$watch('model.modal', function (modal) {
    $scope.show = modal === MODAL.updateAvailable;
  });
}

function UnexpectedStateCtrl($scope, cometdSrvc, apiSrvc, modelSrvc, MODAL, REQUIRED_API_VER, INTERACTION, logFactory) {
  var log = logFactory('UnexpectedStateCtrl');

  $scope.modelSrvc = modelSrvc;

  $scope.show = false;
  $scope.$watch('modelSrvc.sane', function (sane) {
    if (!sane) {
      // disconnect immediately from insane backend
      cometdSrvc.disconnect();
      $scope.report = $scope.defaultReportMsg();
      modelSrvc.model.modal = MODAL.none;
      $scope.show = true;
    }
  });

  $scope.$watch('model.version.installed.api', function (installed) {
    if (angular.isUndefined(installed)) return;
    for (var key in {major: 'major', minor: 'minor'}) {
      if (installed[key] !== REQUIRED_API_VER[key]) {
        log.error('Backend api version', installed, 'incompatible with required version', REQUIRED_API_VER);
        // XXX this might well 404 due to the version mismatch but worth a shot?
        apiSrvc.exception({error: 'versionMismatch', installed: installed, required: REQUIRED_API_VER});
        modelSrvc.sane = false;
        return;
      }
    }
  }, true);

  function handleChoice(choice) {
    $scope.interaction(choice, {notify: $scope.notify, report: $scope.report}).then($scope.reload);
  }
  $scope.handleReset = function () {
    handleChoice(INTERACTION.unexpectedStateReset);
  };
  $scope.handleRefresh = function () {
    handleChoice(INTERACTION.unexpectedStateRefresh);
  };
}

function ContactCtrl($scope, MODAL, CONTACT_FORM_MAXLEN) {
  $scope.CONTACT_FORM_MAXLEN = CONTACT_FORM_MAXLEN;

  $scope.show = false;
  $scope.$watch('model.modal', function (modal) {
    $scope.show = modal === MODAL.contact;
    if ($scope.show) {
      $scope.message = $scope.defaultReportMsg();
      if ($scope.contactForm && $scope.contactForm.contactMsg) {
        $scope.contactForm.contactMsg.$pristine = true;
      }
    }
  });
}

function ConfirmResetCtrl($scope, MODAL) {
  $scope.show = false;
  $scope.$watch('model.modal', function (modal) {
    $scope.show = modal === MODAL.confirmReset;
  });
}

function GiveModeForbiddenCtrl($scope, MODAL) {
  $scope.show = false;
  $scope.$watch('model.modal', function (modal) {
    $scope.show = modal === MODAL.giveModeForbidden;
  });
}

function NotInvitedCtrl($scope, MODAL) {
  $scope.show = false;
  $scope.$watch('model.modal', function (modal) {
    $scope.show = modal === MODAL.notInvited;
  });
}

function FinishedCtrl($scope, MODAL) {
  $scope.autoReport = true;
  $scope.show = false;
  $scope.$watch('model.modal', function (modal) {
    $scope.show = modal === MODAL.finished;
  });
}

function SettingsCtrl($scope, MODAL) {
  $scope.show = false;
  $scope.$watch('model.modal', function (modal) {
    $scope.show = modal === MODAL.settings;
  });

  $scope.$watch('model.settings.runAtSystemStart', function (runAtSystemStart) {
    $scope.runAtSystemStart = runAtSystemStart;
  });

  $scope.$watch('model.settings.showFriendPrompts', function (showFriendPrompts) {
    $scope.showFriendPrompts = showFriendPrompts;
  });

  $scope.$watch('model.settings.autoReport', function (autoReport) {
    $scope.autoReport = autoReport;
  });

  $scope.$watch('model.settings.systemProxy', function (systemProxy) {
    $scope.systemProxy = systemProxy;
  });

  $scope.$watch('model.settings.proxyAllSites', function (proxyAllSites) {
    $scope.proxyAllSites = proxyAllSites;
  });
}

function AuthorizeCtrl($scope, MODAL) {
  $scope.show = false;
  $scope.$watch('model.modal', function (modal) {
    $scope.show = modal === MODAL.authorize;
  });
}

function AboutCtrl($scope, MODAL) {
  $scope.show = false;
  $scope.$watch('model.modal', function (modal) {
    $scope.show = modal === MODAL.about;
  });
}

function ProxiedSitesCtrl($scope, $filter, logFactory, SETTING, INTERACTION, INPUT_PAT, MODAL) {
  var log = logFactory('ProxiedSitesCtrl'),
      fltr = $filter('filter'),
      DOMAIN = INPUT_PAT.DOMAIN,
      IPV4 = INPUT_PAT.IPV4,
      nproxiedSitesMax = 1000,
      proxiedSites = [],
      proxiedSitesDirty = [];

  $scope.show = false;
  $scope.$watch('model.modal', function (modal) {
    $scope.show = modal === MODAL.proxiedSites;
  });

  $scope.$watch('searchText', function (searchText) {
    $scope.inputFiltered = (searchText ? fltr(proxiedSitesDirty, searchText) : proxiedSitesDirty).join('\n');
  });

  function updateComplete() {
    $scope.hasUpdate = false;
    $scope.updating = false;
  }

  function makeValid() {
    $scope.errorLabelKey = '';
    $scope.errorCause = '';
    if ($scope.proxiedSitesForm && $scope.proxiedSitesForm.input) {
      $scope.proxiedSitesForm.input.$setValidity('generic', true);
    }
  }

  $scope.$watch('model.settings.proxiedSites', function(proxiedSites_) {
    if (proxiedSites) {
      proxiedSites = normalizedLines(proxiedSites_);
      $scope.input = proxiedSites.join('\n');
      updateComplete();
      makeValid();
      proxiedSitesDirty = _.cloneDeep(proxiedSites);
    }
  }, true);
  $scope.$watch('model.nproxiedSitesMax', function(nproxiedSitesMax_) {
    nproxiedSitesMax = nproxiedSitesMax_;
    if ($scope.input)
      $scope.validate($scope.input);
  }, true);

  function normalizedLine (domainOrIP) {
    return angular.lowercase(domainOrIP.trim());
  }

  function normalizedLines (lines) {
    return _.map(lines, normalizedLine);
  }

  $scope.validate = function (value) {
    if (!value || !value.length) {
      $scope.errorLabelKey = 'ERROR_ONE_REQUIRED';
      $scope.errorCause = '';
      return false;
    }
    if (angular.isString(value)) value = value.split('\n');
    proxiedSitesDirty = [];
    var uniq = {};
    $scope.errorLabelKey = '';
    $scope.errorCause = '';
    for (var i=0, line=value[i], l=value.length, normline;
         i<l && !$scope.errorLabelKey;
         line=value[++i]) {
      normline = normalizedLine(line);
      if (!normline) continue;
      if (!(DOMAIN.test(normline) ||
            IPV4.test(normline))) {
        $scope.errorLabelKey = 'ERROR_INVALID_LINE';
        $scope.errorCause = line;
      } else if (!(normline in uniq)) {
        proxiedSitesDirty.push(normline);
        uniq[normline] = true;
      }
    }
    if (proxiedSitesDirty.length > nproxiedSitesMax) {
      $scope.errorLabelKey = 'ERROR_MAX_PROXIED_SITES_EXCEEDED';
      $scope.errorCause = '';
    }
    $scope.hasUpdate = !_.isEqual(proxiedSites, proxiedSitesDirty);
    return !$scope.errorLabelKey;
  };

  $scope.handleReset = function () {
    $scope.input = proxiedSites.join('\n');
    makeValid();
  };

  $scope.handleContinue = function () {
    if ($scope.proxiedSitesForm.$invalid) {
      log.debug('invalid input, not sending update');
      return $scope.interaction(INTERACTION.continue);
    }
    if (!$scope.hasUpdate) {
      log.debug('input matches original, not sending update');
      return $scope.interaction(INTERACTION.continue);
    }
    log.debug('sending update');
    $scope.input = proxiedSitesDirty.join('\n');
    $scope.updating = true;
    $scope.changeSetting(SETTING.proxiedSites, proxiedSitesDirty).then(function () {
      updateComplete();
      log.debug('update complete, sending continue');
      $scope.interaction(INTERACTION.continue);
    }, function () {
      $scope.updating = false;
      $scope.errorLabelKey = 'ERROR_SETTING_PROXIED_SITES';
      $scope.errorCause = '';
    });
  };
}

function LanternFriendsCtrl($scope, $timeout, logFactory, $filter, INPUT_PAT, FRIEND_STATUS, INTERACTION, MODAL) {
  var log = logFactory('LanternFriendsCtrl'),
      EMAIL = INPUT_PAT.EMAIL_INSIDE,
      dateFltr = $filter('date'),
      filterFltr = $filter('filter'),
      i18nFltr = $filter('i18n'),
      notRejectedFltr = $filter('notRejected'),
      orderByFltr = $filter('orderBy'),
      prettyBpsFltr = $filter('prettyBps'),
      prettyUserFltr = $filter('prettyUser');

  $scope.show = false;
  $scope.$watch('model.modal', function (modal) {
    $scope.show = modal === MODAL.lanternFriends;
  });

  $scope.$watch('added', function (added) {
    if (!added) return;
    $scope.add();
  }, true);

  $scope.add = function (email) {
    email = email || $scope.added.email;
    if (!email) {
      log.error('missing email');
      return;
    }
    $scope.errorLabelKey = '';
    $scope.interaction(INTERACTION.friend, {email: email}).then(
      function () {
        $scope.added = null;
        $scope.$broadcast('addSuccess');
      },
      function () {
        $scope.errorLabelKey = 'ERROR_OPERATION_FAILED';
      });
  };

  $scope.reject = function (email) {
    $scope.errorLabelKey = '';
    $scope.interaction(INTERACTION.reject, {email: email}).then(
      null,
      function () {
        $scope.errorLabelKey = 'ERROR_OPERATION_FAILED';
      });
  };

  function updateDisplayedFriends() {
    $scope.displayedFriends =
      orderByFltr(
        filterFltr(
          notRejectedFltr(
            filterFltr(
              model.friends,
              matchSearchText)),
          addConnectedStatus),
        friendOrder);
  }
  $scope.$watch('model.friends', updateDisplayedFriends, true);
  $scope.$watch('searchText', updateDisplayedFriends, true);

  function matchSearchText(friend) {
    if (!$scope.searchText ||
        ~angular.lowercase(prettyUserFltr(friend))
          .indexOf(angular.lowercase($scope.searchText))) {
      return friend;
    }
    return false;
  }

  function addConnectedStatus(friend) {
    // XXX should use a better id than email
    var peers = _.filter(model.peers, {rosterEntry: {email: friend.email}});
    if (peers.length) {
      var bpsUpDnSum = _.reduce(peers, function(sum, peer){return sum+(peer.bpsUpDn||0);}, 0);
      if (bpsUpDnSum) {
        friend.connectedStatus = prettyBpsFltr(bpsUpDnSum)+' '+i18nFltr('TRANSFERRING_NOW');
      } else {
        if (_.any(peers, 'connected')) {
          friend.connectedStatus = i18nFltr('CONNECTED');
        } else {
          var lastConnected = _.reduce(peers, function (mostRecent, peer) {
              return mostRecent >= (peer.lastConnected || '') ? mostRecent : peer.lastConnected;
            },
            '');
          if (lastConnected) {
            friend.connectedStatus = i18nFltr('LAST_CONNECTED')+' '+dateFltr(lastConnected, 'short');
          } else {
            friend.connectedStatus = i18nFltr('NOT_YET_CONNECTED');
          }
        }
      }
    } else {
      friend.connectedStatus = i18nFltr('NOT_YET_CONNECTED');
    }
    return friend;
  }

  function friendOrder(friend) {
    // entries with status 'pending' come first, then 'friend', then other
    // within each group, entries with no name field come first
    // ('-' < '0' < 'A' < 'a')
    var s = friend.name ? prettyUserFltr(friend) : '-' + friend.email;
    switch (friend.status) {
      case FRIEND_STATUS.pending:
        return '0' + s;
      case FRIEND_STATUS.friend:
        return '1' + s;
      default:
        return '2' + s;
    }
  }

  $scope.$watch('contactCompletions', function (contactCompletions) {
    var data = _.map(contactCompletions, function (c) {
      return angular.extend({}, c, {id: c.email, text: prettyUserFltr(c)});
    });
    angular.copy(data, $scope.select2opts.data);
  });

  $scope.select2opts = {
    allowClear: true,
    data: [],
    createSearchChoice: function (input) {
      var match = input.match(EMAIL);
      if (match) {
        match = match[0];
        return {id: match, text: match, email: match};
      }
    },
    formatNoMatches: function () {
      return i18nFltr('ENTER_VALID_EMAIL');
    },
    formatSearching: function () {
      return i18nFltr('SEARCHING_ELLIPSIS');
    },
    width: '100%'
  };
}

function ScenariosCtrl($scope, $timeout, logFactory, MODAL, INTERACTION) {
  var log = logFactory('ScenariosCtrl');

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
