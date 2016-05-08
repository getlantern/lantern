'use strict';

app.controller('RootCtrl', ['$rootScope', '$scope', '$filter', '$compile', '$window', '$http', 'gaMgr', '$translate',
               'localStorageService', 'BUILD_REVISION',
               function($rootScope, $scope, $filter, $compile, $window, $http, gaMgr, $translate, localStorageService, BUILD_REVISION) {
    $scope.currentModal = 'none';

    $rootScope.lanternShowNews = 'lanternShowNewsFeed';
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

    $rootScope.mobileAppLink = function() {
      return "https://bit.ly/lanternapk";
    };

    $rootScope.mobileShareContent = function() {
      var fmt = $filter('translate')('LANTERN_MOBILE_SHARE');
      return fmt.replace("%s", $rootScope.mobileAppLink());
    };

    $rootScope.sendMobileAppLink = function() {
      var email = $scope.email;

      $scope.resetPlaceholder();

      if (!email || !(/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email))) {
        $scope.inputClass = "fail";
        var t = $filter('translate');
        $scope.inputPlaceholder = t("LANTERN_MOBILE_ENTER_VALID_EMAIL");
        alert(t("LANTERN_MOBILE_CHECK_EMAIL"));
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


    $rootScope.showError = false;
    $rootScope.showBookmarks = true;
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
    gaMgr.trackCopyLink();
  };

  $scope.trackSocialLink = function(name) {
    gaMgr.trackSocialLink(name);
  };

  $scope.trackLink = function(name) {
    gaMgr.trackLink(name);
  };

}]);

app.controller('NewsfeedCtrl', ['$scope', '$rootScope', '$translate', 'gaMgr', 'localStorageService', function($scope, $rootScope, $translate, gaMgr, localStorageService) {
  $rootScope.showNewsfeed = function() {
    $rootScope.showNews = true;
    localStorageService.set($rootScope.lanternShowNews, true);
    $rootScope.showMobileAd = false;
    $rootScope.showBookmarks = false;
    gaMgr.trackShowFeed();
  };
  $rootScope.hideNewsfeed = function() {
    $rootScope.showNews = false;
    localStorageService.set($rootScope.lanternShowNews, false);
    $rootScope.showMobileAd = false;
    $rootScope.showBookmarks = true;
    $rootScope.showError = false;
    gaMgr.trackHideFeed();
  };
  $rootScope.showNewsfeedError = function() {
    console.log("Newsfeed error");
    // If we're currently in newsfeed mode, we want to show the error
    // and also not show the bookmarks, as otherwise the two will
    // overlap.
    if ($rootScope.showNews) {
      $rootScope.showBookmarks = false;
    }
    $rootScope.showNews = false;
    $rootScope.enableShowError();
  };

  // Note local storage stores everything as strings.
  if (localStorageService.get($rootScope.lanternShowNews) === "true") {
    console.log("local storage set to show the feed");

    // We just set the variable directly here to skip analytics, local
    // storage, etc.
    $rootScope.showNews = true;
  } else {
    console.log("local storage NOT set to show the feed");
    $rootScope.showNews = false;
  }

  // The function for determing the URL of the feed. Note this is watched
  // elsewhere so will get called a lot, but it's just calculating the url
  // string so is cheap.
  $scope.feedUrl = function() {
    var mapTable = {
      'fa': 'fa_IR',
      'zh': 'zh_CN'
    };
    var lang = $translate.use();
    lang = mapTable[lang] || lang;
    var url = "/feed?lang="+lang;
    return url;
  }
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
  var count = 0;
  $scope.tabVisible = function() {
    return $scope.tabSelected($scope.feedsTitle);
  };
  $scope.addMoreItems = function() {
    if ($scope.tabVisible()) {
      var more = copiedFeedEntries.splice(0, 10);
      $scope.entries = $scope.entries.concat(more);
      //console.log($scope.feedsTitle + ": added " + more.length + " entries, total " + $scope.entries.length);
    }
  };
  $scope.renderContent = function(feed) {
    if (feed.meta && feed.meta.description) {
      return feed.meta.description;
    }
    return feed.contentSnippetText;
  };
  $scope.trackFeed = function(name) {
    return gaMgr.trackFeed(name);
  };
  $scope.hideImage = function(feed) {
    feed.image = null;
  };
  $scope.addMoreItems();
}]);

app.controller('ErrorCtrl', ['$scope', '$rootScope', 'gaMgr', '$sce', '$translate', "deviceDetector",
  function($scope, $rootScope, gaMgr, $sce, $translate, deviceDetector) {
    // TOOD: notify GA we've hit the error page!

    $scope.isMac = function() {
      return deviceDetector.os == "mac";
    }

    $scope.isWindows = function() {
      return deviceDetector.os == "windows";
    }

    $scope.isWindowsXp = function() {
      return deviceDetector.os == "windows" &&
        deviceDetector.os_version == "windows-xp"
    }

    $scope.isLinux = function() {
      return deviceDetector.os == "linux";
    }

    $rootScope.enableShowError = function() {
      $rootScope.showError = true;
      gaMgr.trackFeed("error");
    }

    $scope.showProxyOffHelp = false;
    $scope.showExtensionHelp = false;
    $scope.showXunleiHelp = false;
    $scope.showConnectionHelp = false;

    $scope.toggleShowProxyOffHelp = function() {
      $scope.showProxyOffHelp = !$scope.showProxyOffHelp;
    }
    $scope.toggleShowExtensionHelp = function() {
      $scope.showExtensionHelp = !$scope.showExtensionHelp;
    }
    $scope.toggleShowXunleiHelp = function() {
      $scope.showXunleiHelp = !$scope.showXunleiHelp;
    }

    $scope.toggleShowConnectionHelp = function() {
      $translate('CONNECTION_HELP')
        .then(function (translatedVal) {
          $rootScope.connectionHelpText = translatedVal;
        });

      $scope.showConnectionHelp = !$scope.showConnectionHelp;
    }
}]);
