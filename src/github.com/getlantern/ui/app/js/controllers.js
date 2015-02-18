'use strict';

app.controller('RootCtrl', ['$scope', '$http', 'flashlightStats', function($scope, $http, flashlightStats) {
    // disabling for now flashlightStats.connect();
    $scope.currentModal = 'none';

    $scope.showModal = function(val) {
        $scope.currentModal = val;
    };

    $scope.closeModal = function() {
        $scope.currentModal = 'none';
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

app.controller('SettingsCtrl', ['$scope', 'MODAL', function($scope, MODAL) {
  $scope.show = false;

  $scope.$watch('model.modal', function (modal) {
    $scope.show = modal === MODAL.settings;
  });

  $scope.$watch('model.settings.runAtSystemStart', function (runAtSystemStart) {
    $scope.runAtSystemStart = runAtSystemStart;
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
