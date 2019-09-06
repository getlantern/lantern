'use strict';

/*
Feeds directive shows localStorge cached feeds if available, and fetch server
in same time. It re-renders the feeds when remote feeds fetched, or calls
onError() if failed to fetch.
*/
angular.module('feeds-directives', []).directive('feed', ['feedService', '$compile', '$templateCache', '$http', function (feedService, $compile, $templateCache, $http) {
  return  {
    restrict: 'E',
    scope: {
      summary: '=',
      onFeedsLoaded: '&',
      onError: '&onError'
    },
    controller: ['$scope', '$element', '$attrs', '$q', '$sce', '$timeout', 'feedCache', 'gaMgr', function ($scope, $element, $attrs, $q, $sce, $timeout, feedCache, gaMgr) {
      $scope.$watch('finishedLoading', function (value) {
        if ($attrs.postRender && value) {
          $timeout(function () {
            new Function("element", $attrs.postRender + '(element);')($element);
          }, 0);
        }
      });

      var spinner = $templateCache.get('feed-spinner.html');
      $element.append($compile(spinner)($scope));

      function sanitizeFeedEntry(feedEntry) {
        feedEntry.title = $sce.trustAsHtml(feedEntry.title);
        feedEntry.contentSnippet = $sce.trustAsHtml(feedEntry.contentSnippet);
        feedEntry.content = $sce.trustAsHtml(feedEntry.content);
        feedEntry.publishedDate = new Date(feedEntry.publishedDate).getTime();
        return feedEntry;
      }

      // Add/replace below fields to an entry:
      // 1. the source field of an entry is the key of the feed, we need the feed title instead.
      // 2. if the feed one entry belongs to needs to be excluded from All tab, apply to the entry itself.
      function updateEntryFields(feedEntry, feeds) {
          var source = feedEntry.source;
          if (source) {
            var feed = feeds[source];
            feedEntry.excludeFromAll = feed.excludeFromAll;
            if (feed && feed.title) {
              feedEntry.source = feed.title;
            }
          }
      }

      function sanitizeEntries(entries, feeds) {
        for (var i = 0; i < entries.length; i++) {
          sanitizeFeedEntry(entries[i]);
          updateEntryFields(entries[i], feeds);
        }
      }

      // convert the feeds object to an array with the order specified by an array of keys.
      function sort(feeds, order) {
        var sorted = []
        for (var key in order) {
          var item = feeds[order[key]]
          if (item) {
            sorted.push(item)
          } else {
            console.error("feed " + item + " is not found in feeds!")
          }
        }
        return sorted
      }

      // feeds.entries is a list of indexes in allEntries, replace them with actual entries
      function replaceWithRealEntries(feeds, allEntries) {
        for (var i in feeds) {
          var feedEntries = feeds[i].entries
          for (var j in feedEntries) {
            feedEntries[j] = allEntries[feedEntries[j]]
          }
        }
        return feeds
      }

      var templateRendered = false;
      function renderTemplate(templateHTML) {
        if (!templateRendered) {
          $element.append($compile(templateHTML)($scope));
        }
        templateRendered = true;
      }

      function render(feedsObj) {
        sanitizeEntries(feedsObj.entries, feedsObj.feeds);
        $scope.allEntries = feedsObj.entries;
        $scope.allFeeds = replaceWithRealEntries(sort(feedsObj.feeds, feedsObj.sorted_feeds), feedsObj.entries);
        if ($attrs.templateUrl) {
          $http.get($attrs.templateUrl, {cache: $templateCache}).success(function (templateHtml) {
            renderTemplate(templateHtml);
          });
        }
        else {
          renderTemplate($templateCache.get('feed-list.html'));
        }
      }

      $attrs.$observe('url', function(url){
        var deferred = $q.defer();
        var feedsObj = feedCache.get(url);
        if (feedsObj) {
          console.log("show feeds in cache");
          render(feedsObj);
          deferred.resolve(feedsObj);
        }

        feedService.getFeeds(url, $attrs.fallbackUrl, gaMgr).then(function (feedsObj) {
          console.log("fresh copy of feeds loaded");
          feedCache.set(url, feedsObj);
          render(feedsObj);
          deferred.resolve(feedsObj);
        },function (error) {
          if (feedsObj) {
            console.log("Using cached feed");
            return;
          }
          console.error("fail to fetch feeds: " +  error);
          if ($scope.onError) {
            $scope.onError(error);
          }
          $scope.error = error;
        });

        deferred.promise.then(function(feedsObj) {
          if ($scope.onFeedsLoaded) {
            $scope.onFeedsLoaded();
          }
        }).finally(function () {
          $element.find('.spinner').slideUp();
          $scope.$evalAsync('finishedLoading = true')
        });

      });
    }]
  };
}]);
