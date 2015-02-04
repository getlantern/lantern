'use strict';

app.controller('RootCtrl', ['$scope', 'flashlightStats', function($scope, flashlightStats) {
    //flashlightStats.connect();
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

app.controller('ProxiedSitesCtrl', ['$scope', '$filter', 'SETTING', 'INTERACTION', 'INPUT_PAT', 'MODAL', function($scope, $filter, SETTING, INTERACTION, INPUT_PAT, MODAL) {
      var fltr = $filter('filter'),
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
      //log.debug('invalid input, not sending update');
      return $scope.interaction(INTERACTION.continue);
    }
    if (!$scope.hasUpdate) {
      //log.debug('input matches original, not sending update');
      return $scope.interaction(INTERACTION.continue);
    }
    //log.debug('sending update');
    $scope.input = proxiedSitesDirty.join('\n');
    $scope.updating = true;
    $scope.changeSetting(SETTING.proxiedSites, proxiedSitesDirty).then(function () {
      updateComplete();
      //log.debug('update complete, sending continue');
      $scope.interaction(INTERACTION.continue);
    }, function () {
      $scope.updating = false;
      $scope.errorLabelKey = 'ERROR_SETTING_PROXIED_SITES';
      $scope.errorCause = '';
    });
  };
}]);
