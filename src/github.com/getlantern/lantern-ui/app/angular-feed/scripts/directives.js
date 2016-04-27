'use strict';

angular.module('feeds-directives', []).directive('feed', ['feedService', '$compile', '$templateCache', '$http', function (feedService, $compile, $templateCache, $http) {
  return  {
    restrict: 'E',
    scope: {
      summary: '=',
      onFeedsLoaded: '&',
      onError: '&onError'
    },
    controller: ['$scope', '$element', '$attrs', '$q', '$sce', '$timeout', 'feedCache', function ($scope, $element, $attrs, $q, $sce, $timeout, feedCache) {
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

      function sanitizeEntries(entries) {
        for (var i = 0; i < entries.length; i++) {
          sanitizeFeedEntry(entries[i]);
        }
      }

      function renderTemplate(templateHTML, feedsObj) {
        $scope.allEntries = feedsObj.entries;
        $scope.allFeeds = feedsObj.feeds;
        $element.append($compile(templateHTML)($scope));
      }

      function render(feedsObj) {
        sanitizeEntries(feedsObj.entries);
        if ($attrs.templateUrl) {
          $http.get($attrs.templateUrl, {cache: $templateCache}).success(function (templateHtml) {
            renderTemplate(templateHtml, feedsObj);
          });
        }
        else {
          renderTemplate($templateCache.get('feed-list.html'), feedsObj);
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
        feedService.getFeeds(url, $attrs.fallbackUrl).then(function (feedsObj) {
          console.log("fresh copy of feeds loaded");
          feedCache.set(url, feedsObj);
          render(feedsObj);
          deferred.resolve(feedsObj);
        },function (error) {
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
