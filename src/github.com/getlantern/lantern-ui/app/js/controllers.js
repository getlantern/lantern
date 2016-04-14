'use strict';

app.controller('RootCtrl', ['$rootScope', '$scope', '$compile', '$window', '$http', 'gaMgr', '$translate',
               'localStorageService', 'BUILD_REVISION',
               function($rootScope, $scope, $compile, $window, $http, gaMgr, $translate, localStorageService, BUILD_REVISION) {
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

    $rootScope.mobileAdImgPath = function(name) {
      var mapTable = {
        'zh_CN': 'zh',
        'zh': 'zh',
        'fa_IR': 'fa',
        'fa': 'fa'
      };
      var lang = $translate.use();
      lang = mapTable[lang] || 'en';
      return '/img/mobile-ad/' + lang + '/' + name;
    }

    $rootScope.setShowMobileAd = function() {
      $rootScope.showMobileAd = true;
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

    /*if (!localStorageService.get($rootScope.lanternHideMobileAdVar)) {
      $scope.resetPlaceholder();
      $rootScope.showMobileAd = true;
    };*/


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

app.controller('NewsfeedCtrl', ['$scope', '$rootScope', '$translate', function($scope, $rootScope, $translate) {
  $scope.showNewsfeed = function(e) {
    $rootScope.showNews = true;
  };
  $scope.hideNewsfeed = function(e) {
    $rootScope.showNews = false;
  };
  $scope.showNewsfeed();

  $scope.feedUrl = function() {
    var mapTable = { 'fa': 'fa_IR' };
    var lang = $translate.use();
    lang = mapTable[lang] || lang;
    return "https://feeds.getiantem.org/" + lang + "/feed.json";
  };

}]);

app.controller('FeedTabCtrl', ['$scope', '$rootScope', '$translate', function($scope, $rootScope, $translate) {
  $scope.tabActive = {};
  $scope.selectTab = function (title) {
    $scope.tabActive[title] = true;
  };
  $scope.deselectTab = function (title) {
    $scope.tabActive[title] = false;
  };
  $scope.tabSelected = function (title) {
    return $scope.tabActive[title] === true;
  };
}]);

app.controller('FeedCtrl', ['$scope', 'gaMgr', function($scope, gaMgr) {
  var copiedFeedEntries = [];
  angular.copy($scope.feedEntries, copiedFeedEntries);
  $scope.entries = [];
  $scope.containerId = function($index) {
    return "#feeds-container-" + $index;
  };
  $scope.addMoreItems = function() {
    if ($scope.tabSelected($scope.feedsTitle)) {
      var more = copiedFeedEntries.splice(0, 10);
      $scope.entries = $scope.entries.concat(more);
      console.log($scope.feedsTitle + ": added " + more.length + " entries, total " + $scope.entries.length);
    }
  };
  $scope.renderContent = function(feed) {
    if (feed.meta && feed.meta.description) {
      return feed.meta.description;
    }
    return feed.contentSnippet;
  };
  $scope.trackFeed = function(name) {
    return gaMgr.trackFeed(name);
  };
  $scope.addMoreItems();
}]);
