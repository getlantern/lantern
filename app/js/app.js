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
  .run(function ($filter, $log, $rootScope, $timeout, $window, apiSrvc, modelSrvc, ENUMS, EXTERNAL_URL, LANTERNUI_VER) {
    var CONNECTIVITY = ENUMS.CONNECTIVITY,
        MODE = ENUMS.MODE,
        i18nFltr = $filter('i18n'),
        jsonFltr = $filter('json'),
        prettyUserFltr = $filter('prettyUser'),
        reportedStateFltr = $filter('reportedState');

    // for easier inspection in the JavaScript console
    $window.rootScope = $rootScope;
    $window.model = modelSrvc.model;

    $rootScope.EXTERNAL_URL = EXTERNAL_URL;
    $rootScope.lanternUiVersion = LANTERNUI_VER.join('.');
    $rootScope.model = modelSrvc.model;
    $rootScope.DEFAULT_AVATAR_URL = 'img/default-avatar.png';

    angular.forEach(ENUMS, function(val, key) {
      $rootScope[key] = val;
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
      $rootScope.friendsByEmail = {};
      $rootScope.nfriends = 0;
      $rootScope.npending = 0;
      for (var i=0, l=friends.length, ii=friends[i]; ii; ii=friends[++i]) {
        $rootScope.friendsByEmail[ii.email] = ii;
        if (ii.status === FRIEND_STATUS.pending) {
          $rootScope.npending++;
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
      for (var i=0, l=model.friends.length, ii=model.friends[i]; ii; ii=model.friends[++i]) {
        if (ii.status !== FRIEND_STATUS.friend) {
          completions[ii.email] = ii;
        }
      }
      if ($rootScope.friendsByEmail) {
        for (var i=0, l=roster.length, ii=roster[i]; ii; ii=roster[++i]) {
          var email = ii.email, friend = email && $rootScope.friendsByEmail[email];
          if (email && (!friend || friend.status !== FRIEND_STATUS.friend)) {
            // if an entry for this email was added in the previous loop, we want
            // this entry to overwrite it since the roster object has more data
            completions[ii.email] = ii;
          }
        }
      }
      completions = _.sortBy(completions, function (i) { return prettyUserFltr(i); }); // XXX sort by contact frequency instead
      $rootScope.contactCompletions = completions;
    }

    $rootScope.reload = function () {
      location.reload(true); // true to bypass cache and force request to server
    };

    $rootScope.interaction = function (interactionid, extra) {
      return apiSrvc.interaction(interactionid, extra)
        .success(function(data, status, headers, config) {
          $log.debug('interaction(', interactionid, extra || '', ') successful');
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

    $rootScope.defaultReportMsg = function() {
      var reportedState = jsonFltr(reportedStateFltr($rootScope.model));
      return i18nFltr('MESSAGE_PLACEHOLDER') + reportedState;
    };
  });
