'use strict';

angular.module('feeds-services', []).factory('feedService', ['$q', '$http', '$sce', 'feedCache', function ($q, $http, $sce, feedCache) {

    function sanitizeFeedEntry(feedEntry) {
      feedEntry.title = $sce.trustAsHtml(feedEntry.title);
      feedEntry.contentSnippet = $sce.trustAsHtml(feedEntry.contentSnippet);
      feedEntry.content = $sce.trustAsHtml(feedEntry.content);
      feedEntry.publishedDate = new Date(feedEntry.publishedDate).getTime();
      return feedEntry;
    }

    function sanitizeEntries(entries) {
      for (var i = 0; i < entries.length; i++) {
        sanitizeFeedEntry(entries[i]);
      }
    }

    var getFeeds = function (feedURL, count) {
      var deferred = $q.defer();

      /*if (feedCache.hasCache(feedURL)) {
        var entries = feedCache.get(feedURL);
        sanitizeEntries(entries);
        deferred.resolve(entries);
      }*/


      /*if (count) {
        feed.includeHistoricalEntries();
        feed.setNumEntries(count);
      }*/

      $http.get(feedURL).then(
        function(response) {
        if (response.status != 200) {
          deferred.reject(new Error("invalid HTTP status: " + response.status));
          return
        }
        var data = response.data
        if (!data.entries) {
          deferred.reject(new Error("invalid data format"));
          return
        }
        //feedCache.set(feedURL, data.feed.entries);
        sanitizeEntries(data.entries);
        deferred.resolve(data);
      }, function(response) {
        deferred.reject(response.error);
      });
      return deferred.promise;
    };

    return {
      getFeeds: getFeeds
    };
}])
.factory('feedCache', function () {
  var CACHE_INTERVAL = 1000 * 60 * 5; //5 minutes

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
      localStorage.setItem(name, angular.toJson(obj));
      var CACHE_TIMES = cacheTimes();
      CACHE_TIMES[name] = new Date().getTime();
      localStorage.setItem('CACHE_TIMES', angular.toJson(CACHE_TIMES));
    },
    get: function (name) {
      if (hasCache(name)) {
        return angular.fromJson(localStorage.getItem(name));
      }
      return null;
    },
    hasCache: hasCache
  };
});
