'use strict';

app.controller('RootCtrl', ['$rootScope', '$scope', '$compile', '$window', '$http', 'gaMgr',
               'localStorageService', 'BUILD_REVISION',
               function($rootScope, $scope, $compile, $window, $http, gaMgr, localStorageService, BUILD_REVISION) {
    $scope.currentModal = 'none';

    $rootScope.lanternFirstTimeBuildVar = 'lanternFirstTimeBuild-'+BUILD_REVISION;
    $rootScope.lanternHideMobileAdVar = 'lanternHideMobileAd';

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
      $scope.closeModal();

      if (val == 'welcome') {
        $scope.loadShareScripts();
      } else {
        $('<div class="modal-backdrop"></div>').appendTo(document.body);
      }

      $scope.currentModal = val;
    };

    $scope.$watch('model.email', function(email) {
      $scope.email = email;
    });

    $scope.resetPlaceholder = function() {
      $scope.inputClass = "";
      $scope.inputPlaceholder = "you@example.com";
    }

    $rootScope.hideMobileAd = function() {
      $rootScope.showMobileAd = false;
      localStorageService.set($rootScope.lanternHideMobileAdVar, true);
    };

    $rootScope.sendMobileAppLink = function() {
      var email = $scope.email;

      $scope.resetPlaceholder();

      if (!email || !(/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email))) {
        $scope.inputClass = "fail";
        $scope.inputPlaceholder = "Please enter a valid e-mail";
        alert("Please check your e-mail address.");
        return;
      }

      mailer.send({
        'to': email,
        'template': 'lantern-mobile-message'
      });

      $rootScope.hideMobileAd();

      $scope.showModal("lantern-mobile-ad");

      gaMgr.trackSendLinkToMobile();
    };


    $scope.trackBookmark = function(name) {
      return gaMgr.trackBookmark(name);
    };

    $scope.trackLink = function(name) {
      return gaMgr.trackLink(name);
    };

    $scope.closeModal = function() {
      $rootScope.hideMobileAd();

      $scope.currentModal = 'none';
      $(".modal-backdrop").remove();
    };

    if (!localStorageService.get($rootScope.lanternFirstTimeBuildVar)) {
      // Force showing Ad.
      localStorageService.set($rootScope.lanternHideMobileAdVar, "");
      // Saving first time run.
      localStorageService.set($rootScope.lanternFirstTimeBuildVar, true);
    };

    if (!localStorageService.get($rootScope.lanternHideMobileAdVar)) {
      $scope.resetPlaceholder();
      $rootScope.showMobileAd = true;
    };


}]);

app.controller('SettingsCtrl', ['$scope', 'MODAL', 'DataStream', 'gaMgr', function($scope, MODAL, DataStream, gaMgr) {
  $scope.show = false;

  $scope.$watch('model.modal', function (modal) {
    $scope.show = modal === MODAL.settings;
  });

  $scope.changeReporting = function(value) {
      DataStream.send('settings', {autoReport: value});
  };

  $scope.changeAutoLaunch = function(value) {
      DataStream.send('settings', {autoLaunch: value});
  }

  $scope.changeProxyAll = function(value) {
      DataStream.send('settings', {proxyAll: value});
  }

  $scope.changeSystemProxy = function(value) {
      DataStream.send('settings', {systemProxy: value});
  }

  $scope.$watch('model.settings.systemProxy', function(value) {
    $scope.systemProxy = value;
  });

  $scope.$watch('model.settings.proxyAll', function(value) {
    $scope.proxyAllSites = value;
  });
}]);

app.controller('MobileAdCtrl', ['$scope', 'MODAL', 'gaMgr', function($scope, MODAL, gaMgr) {
  $scope.show = false;

  $scope.$watch('model.modal', function (modal) {
    $scope.show = modal === MODAL.settings;
  });

  $scope.copyAndroidMobileLink = function() {
    $scope.linkCopied = true;
    //$scope.closeModal();
    gaMgr.trackCopyLink();
  };

  $scope.trackSocialLink = function(name) {
    gaMgr.trackSocialLink(name);
  };

  $scope.trackLink = function(name) {
    gaMgr.trackLink(name);
  };

}]);
