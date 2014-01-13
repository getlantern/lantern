'use strict';

var app = angular.module('app', [
  'app.constants',
  'app.helpers',
  'app.i18n',
  'app.filters',
  'app.services',
  'app.directives',
  'app.vis',
  'ngSanitize',
  'ui.event',
  'ui.if',
  'ui.showhide',
  'ui.select2',
  'ui.validate',
  'ui.bootstrap'
  ])
  // angular ui bootstrap config
  .config(function($dialogProvider) {
    $dialogProvider.options({
      backdrop: false,
      dialogFade: true,
      keyboard: false,
      backdropClick: false
    });
  })
  .config(function($tooltipProvider) {
    $tooltipProvider.options({
      appendToBody: true
    });
  })
  // angular-ui config
  .value('ui.config', {
    animate: 'ui-hide',
  })
  .run(function ($filter, $log, $rootScope, $timeout, $window, apiSrvc, gaMgr, modelSrvc, ENUMS, EXTERNAL_URL, LANTERNUI_VER, MODAL, CONTACT_FORM_MAXLEN) {
    var CONNECTIVITY = ENUMS.CONNECTIVITY,
        MODE = ENUMS.MODE,
        i18nFltr = $filter('i18n'),
        jsonFltr = $filter('json'),
        model = modelSrvc.model,
        prettyUserFltr = $filter('prettyUser'),
        reportedStateFltr = $filter('reportedState');

    // for easier inspection in the JavaScript console
    $window.rootScope = $rootScope;
    $window.model = model;

    $rootScope.EXTERNAL_URL = EXTERNAL_URL;
    $rootScope.lanternUiVersion = LANTERNUI_VER.join('.');
    $rootScope.model = model;
    $rootScope.DEFAULT_AVATAR_URL = 'img/default-avatar.png';
    $rootScope.CONTACT_FORM_MAXLEN = CONTACT_FORM_MAXLEN;

    angular.forEach(ENUMS, function(val, key) {
      $rootScope[key] = val;
    });

    $rootScope.$watch('model.settings.autoReport', function (autoReport, autoReportOld) {
      if (!model.setupComplete) return;
      if (!autoReport && autoReportOld) {
        gaMgr.stopTracking();
      } else if (autoReport && !autoReportOld) {
        gaMgr.startTracking();
      }
    });

    $rootScope.$watch('model.modal', function (modal, modalOld) {
      if (!model.setupComplete || !model.settings.autoReport || angular.isUndefined(modalOld)) {
        return;
      }
      gaMgr.trackPageView('start');
    });

    $rootScope.$watch('model.notifications', function (notifications) {
      _.each(notifications, function(notification, id) {
        if (notification.autoClose) {
          $timeout(function() {
            $rootScope.interaction(INTERACTION.close, {notification: id, auto: true});
          }, notification.autoClose * 1000);
        }
      });
    }, true);

    $rootScope.$watch('model.settings.mode', function (mode) {
      $rootScope.inGiveMode = mode === MODE.give;
      $rootScope.inGetMode = mode === MODE.get;
    });

    $rootScope.$watch('model.mock', function (mock) {
      $rootScope.mockBackend = !!mock;
    });

    $rootScope.$watch('model.location.country', function (country) {
      if (country && model.countries[country]) {
        $rootScope.inCensoringCountry = model.countries[country].censors;
      }
    });

    $rootScope.$watch('model.roster', function (roster) {
      if (!roster) return;
      updateContactCompletions();
    }, true);

    $rootScope.$watch('model.friends', function (friends) {
      if (!friends) return;
      $rootScope.nfriends = 0;
      $rootScope.nfriendSuggestions = 0;
      $rootScope.friendSuggestions = [];
      $rootScope.friendsByEmail = {};
      for (var i=0, l=friends.length, ii=friends[i]; ii; ii=friends[++i]) {
        $rootScope.friendsByEmail[ii.email] = ii;
        if (ii.status === FRIEND_STATUS.pending) {
          $rootScope.nfriendSuggestions++;
          $rootScope.friendSuggestions.push(ii);
        } else if (ii.status == FRIEND_STATUS.friend) {
          $rootScope.nfriends++;
        }
      }
      updateContactCompletions();
    }, true);
    
    $rootScope.$watch('model.countries', function(countries) {
      // Calculate total number of users across all countries and add to scope
      // We do this because model.global.nusers is currently inaccurate
      var ever = 0,
          online = 0,
          countryCode,
          country;
      if (countries) {
        for (countryCode in countries) {
          country = countries[countryCode];
          if (country.nusers) {
            ever += country.nusers.ever || 0;
            online += country.nusers.online || 0;
          }
        }
      }
      $rootScope.nusersAcrossCountries = {
          ever: ever,
          online: online
      };
    }, true);

    function updateContactCompletions() {
      var roster = model.roster;
      if (!roster) return;
      var completions = {};
      _.each(model.friends, function (friend) {
        if (friend.status !== FRIEND_STATUS.friend) {
          completions[friend.email] = friend;
        }
      });
      if ($rootScope.friendsByEmail) {
        _.each(roster, function (contact) {
          var email = contact.email, friend = email && $rootScope.friendsByEmail[email];
          if (email && (!friend || friend.status !== FRIEND_STATUS.friend)) {
            // if an entry for this email was added in the previous loop, we want
            // this entry to overwrite it since the roster object has more data
            completions[contact.email] = contact;
          }
        });
      }
      completions = _.sortBy(completions, function (i) { return prettyUserFltr(i); }); // XXX sort by contact frequency instead
      $rootScope.contactCompletions = completions;
    }

    $rootScope.reload = function () {
      location.reload(true); // true to bypass cache and force request to server
    };

    $rootScope.interaction = function (interactionid, extra) {
      var stopTracking = interactionid === INTERACTION.reset && model.modal === MODAL.confirmReset;
      return apiSrvc.interaction(interactionid, extra)
        .success(function(data, status, headers, config) {
          $log.debug('interaction(', interactionid, extra || '', ') successful');
          if (stopTracking) {
            gaMgr.stopTracking();
          }
        })
        .error(function(data, status, headers, config) {
          $log.error('interaction(', interactionid, extra, ') failed');
          apiSrvc.exception({data: data, status: status, headers: headers, config: config});
        });
    };

    $rootScope.changeSetting = function(key, val) {
      var update = {path: '/settings/'+key, value: val};
      return $rootScope.interaction(INTERACTION.set, update);
    };

    $rootScope.changeLang = function(lang) {
      return $rootScope.interaction(INTERACTION.changeLang, {lang: lang});
    };

    $rootScope.openExternal = function(url) {
      if ($rootScope.mockBackend) {
        return $window.open(url);
      } else {
        return $rootScope.interaction(INTERACTION.url, {url: url});
      }
    };

    $rootScope.resetContactForm = function (scope) {
      if (scope.show) {
        var reportedState = jsonFltr(reportedStateFltr(model));
        scope.diagnosticInfo = reportedState;
      }
    };

    $rootScope.interactionWithNotify = function (interactionid, scope, reloadAfter) {
      var extra;
      if (scope.notify) {
        var diagnosticInfo = scope.diagnosticInfo;
        if (diagnosticInfo) {
          try {
            diagnosticInfo = angular.fromJson(diagnosticInfo);
          } catch (e) {
            $log.debug('JSON decode diagnosticInfo', diagnosticInfo, 'failed, passing as-is');
          }
        }
        extra = {
          context: model.modal,
          message: scope.message,
          diagnosticInfo: diagnosticInfo
        };
      }
      $rootScope.interaction(interactionid, extra).then(function () {
        if (reloadAfter) $rootScope.reload();
      });
    };

    /**
     * Checks whether the backend is gone (based on last successful connect time).
     */
    $rootScope.backendIsGone = false;
    $rootScope.$watch("cometdConnected", function(cometdConnected) {
      var MILLIS_UNTIL_BACKEND_CONSIDERED_GONE = 10000;
      if (!cometdConnected) {
        // In 11 seconds, check if we're still not connected
        $timeout(function() {
          var lastConnectedAt = $rootScope.cometdLastConnectedAt;
          if (lastConnectedAt) {
            var timeSinceLastConnected = new Date().getTime() - lastConnectedAt.getTime();
            $log.debug("Time since last connect", timeSinceLastConnected);
            if (timeSinceLastConnected > MILLIS_UNTIL_BACKEND_CONSIDERED_GONE) {
              // If it's been more than 10 seconds since we last connect,
              // treat the backend as gone
              $log.debug("Backend is gone");
              $rootScope.backendIsGone = true;
            } else {
              $rootScope.backendIsGone = false;
            }
          }
        }, MILLIS_UNTIL_BACKEND_CONSIDERED_GONE + 1);
      }
    });
  });
