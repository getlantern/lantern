'use strict';

app.controller('RootCtrl', ['$rootScope', '$scope', '$compile', '$window', '$http', 
               'localStorageService', 
               function($rootScope, $scope, $compile, $window, $http, localStorageService) {
    $scope.currentModal = 'none';

    $scope.loadScript = function(src) {
        (function() { 
            var script  = document.createElement("script")
            script.type = "text/javascript";
            script.src  = src;
            script.async = true;
            var x = document.getElementsByTagName('script')[0];
            x.parentNode.insertBefore(script, x);
        })();
    };
    $scope.loadShareScripts = function() {
        if (!$window.twttr) {
            // inject twitter share widget script
          $scope.loadScript('//platform.twitter.com/widgets.js');
          // load FB share script
          $scope.loadScript('//connect.facebook.net/en_US/sdk.js#appId=1562164690714282&xfbml=1&version=v2.3');
        }
    };

    $scope.showModal = function(val) {
        if (val == 'welcome') {
            $scope.loadShareScripts();
        }

        $scope.currentModal = val;
    };

    $rootScope.lanternWelcomeKey = localStorageService.get('lanternWelcomeKey');

    $scope.closeModal = function() {

        // if it's our first time opening the UI,
        // show the settings modal first immediately followed by
        // the welcome screen
        if ($scope.currentModal == 'welcome' && !$rootScope.lanternWelcomeKey) {
            $rootScope.lanternWelcomeKey = true;
            localStorageService.set('lanternWelcomeKey', true);
        } else {
            $scope.currentModal = 'none';
        }
    };

    if (!$rootScope.lanternWelcomeKey) {
        $scope.showModal('welcome');
    };


}]);

app.controller('UpdateAvailableCtrl', ['$scope', 'MODAL', function($scope, MODAL) {
  $scope.show = false;
  $scope.$watch('model.modal', function (modal) {
    $scope.show = modal === MODAL.updateAvailable;
  });
}]);

app.controller('ContactCtrl', ['$scope', 'MODAL', function($scope, MODAL) {
  $scope.show = false;
  $scope.notify = true; // so the view's interactionWithNotify calls include $scope.message and $scope.diagnosticInfo
  $scope.$watch('model.modal', function (modal) {
    $scope.show = modal === MODAL.contact;
    $scope.resetContactForm($scope);
  });
}]);

app.controller('ConfirmResetCtrl', ['$scope', 'MODAL', function($scope, MODAL) {
  $scope.show = false;
  $scope.$watch('model.modal', function (modal) {
    $scope.show = modal === MODAL.confirmReset;
  });
}]);

app.controller('SettingsCtrl', ['$scope', 'MODAL', 'DataStream', 'gaMgr', function($scope, MODAL, DataStream, gaMgr) {
  $scope.show = false;

  $scope.$watch('model.modal', function (modal) {
    $scope.show = modal === MODAL.settings;
  });

  $scope.changeReporting = function(autoreport) {
      var obj = {
        autoReport: autoreport
      };
      DataStream.send('Settings', obj);
  };

  $scope.changeAutoLaunch = function(autoLaunch) {
      var obj = {
        autoLaunch: autoLaunch
      };
      DataStream.send('Settings', obj);
  }

  $scope.changeProxyAll = function(proxyAll) {
      var obj = {
        proxyAll: proxyAll
      };
      DataStream.send('Settings', obj);
  }

  $scope.$watch('model.settings.systemProxy', function (systemProxy) {
    $scope.systemProxy = systemProxy;
  });

  $scope.$watch('model.settings.proxyAllSites', function (proxyAllSites) {
    $scope.proxyAllSites = proxyAllSites;
  });
}]);

app.controller('ProxiedSitesCtrl', ['$rootScope', '$scope', '$filter', 'SETTING', 'INTERACTION', 'INPUT_PAT', 'MODAL', 'ProxiedSites', function($rootScope, $scope, $filter, SETTING, INTERACTION, INPUT_PAT, MODAL, ProxiedSites) {
      var fltr = $filter('filter'),
      DOMAIN = INPUT_PAT.DOMAIN,
      IPV4 = INPUT_PAT.IPV4,
      nproxiedSitesMax = 10000,
      proxiedSitesDirty = [];

  $scope.proxiedSites = ProxiedSites.entries;

  $scope.arrLowerCase = function(A) {
      if (A) {
        return A.join('|').toLowerCase().split('|');
      } else {
        return [];
      }
  }

  $scope.setFormScope = function(scope) {
      $scope.formScope = scope;
  };

  $scope.resetProxiedSites = function(reset) {
    if (reset) {
        $rootScope.entries = $rootScope.global;
        $scope.input = $scope.proxiedSites;
        makeValid();
    } else {
        $rootScope.entries = $rootScope.originalList;
        $scope.closeModal();
    }
  };

  $scope.show = false;

  $scope.$watch('searchText', function (searchText) {
    if (!searchText ) {
        $rootScope.entries = $rootScope.originalList;
    } else {
        $rootScope.entries = (searchText ? fltr(proxiedSitesDirty, searchText) : proxiedSitesDirty);
    }
  });

  function makeValid() {
    $scope.errorLabelKey = '';
    $scope.errorCause = '';
    if ($scope.proxiedSitesForm && $scope.proxiedSitesForm.input) {
      $scope.proxiedSitesForm.input.$setValidity('generic', true);
    }
  }

  /*$scope.$watch('proxiedSites', function(proxiedSites_) {
    if (proxiedSites) {
      proxiedSites = normalizedLines(proxiedSites_);
      $scope.input = proxiedSites.join('\n');
      makeValid();
      proxiedSitesDirty = _.cloneDeep(proxiedSites);
    }
  }, true);*/

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

  $scope.setDiff  = function(A, B) {
      return A.filter(function (a) {
          return B.indexOf(a) == -1;
      });
  };

  $scope.handleContinue = function () {
    $rootScope.updates = {};

    if ($scope.proxiedSitesForm.$invalid) {
      return $scope.interaction(INTERACTION.continue);
    }

    $scope.entries = $scope.arrLowerCase(proxiedSitesDirty);
    $rootScope.updates.Additions = $scope.setDiff($scope.entries,
                                       $scope.originalList);
    $rootScope.updates.Deletions = $scope.setDiff($scope.originalList, $scope.entries);

    ProxiedSites.update();

    $scope.closeModal();
  };
}]);
