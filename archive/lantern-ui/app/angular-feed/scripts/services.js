'use strict';

angular.module('feeds-services', []).factory('feedService', ['$q', '$http', function ($q, $http, $sce) {

  var getFeeds = function (feedURL, fallbackURL, gaMgr) {
    var deferred = $q.defer();

    var handleResponse = function (response) {
      var data = response.data;
      if (!data.entries) {
        deferred.reject(new Error("invalid data format"));
        return;
      }
      deferred.resolve(data);
    };

    var handleError = function(response) {
      if (response.status) {
        gaMgr.trackFeedError(response.config.url, response.status);
        if (response.config.url !== fallbackURL) {
          $http.get(fallbackURL).then(handleResponse, handleError);
          return;
        }
        deferred.reject(new Error("invalid HTTP status: " + response.status));
        return;
      }
      deferred.reject(response.error);
    };

    $http.get(feedURL).then(handleResponse, handleError);
    return deferred.promise;
  };

  return {
    getFeeds: getFeeds
  };
}])

.factory('feedCache', function () {
  var CACHE_INTERVAL = 1000 * 60 * 50 * 24; // 1 day

  function cacheTimes() {
    if ('CACHE_TIMES' in localStorage) {
      return angular.fromJson(localStorage.getItem('CACHE_TIMES'));
    }
    return {};
  }

  function hasCache(name) {
    var CACHE_TIMES = cacheTimes();
    return name in CACHE_TIMES && name in localStorage && new Date().getTime() - CACHE_TIMES[name] < CACHE_INTERVAL;
  }

  return {
    set: function (name, obj) {
      var str = angular.toJson(obj);
      var compressed = LZString.compressToUTF16(str);
      localStorage.setItem(name, compressed);
      var CACHE_TIMES = cacheTimes();
      CACHE_TIMES[name] = new Date().getTime();
      localStorage.setItem('CACHE_TIMES', angular.toJson(CACHE_TIMES));
    },
    get: function (name) {
      if (hasCache(name)) {
        var compressed = localStorage.getItem(name);
        var str = LZString.decompressFromUTF16(compressed);
        return angular.fromJson(str);
      }
      return null;
    },
    hasCache: hasCache
  };
});
