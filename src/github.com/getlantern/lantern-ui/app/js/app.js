'use strict';

var app = angular.module('app', [
  'app.constants',
  'ngWebSocket',
  'app.helpers',
  'pascalprecht.translate',
  'app.filters',
  'app.services',
  'app.directives',
  'app.vis',
  'ngSanitize',
  'ngResource',
  'ui.utils',
  'ui.showhide',
  'ui.validate',
  'ui.bootstrap',
  'ui.bootstrap.tpls'
  ])
  .directive('dynamic', function ($compile) {
    return {
      restrict: 'A',
      replace: true,
      link: function (scope, ele, attrs) {
        scope.$watch(attrs.dynamic, function(html) {
          ele.html(html);
          $compile(ele.contents())(scope);
        });
      }
    };
  })
  .config(function($tooltipProvider, $httpProvider, 
                   $resourceProvider, $translateProvider, DEFAULT_LANG) {

      $translateProvider.preferredLanguage(DEFAULT_LANG);

      $translateProvider.useStaticFilesLoader({
          prefix: './locale/',
          suffix: '.json'
      });
    $httpProvider.defaults.useXDomain = true;
    delete $httpProvider.defaults.headers.common["X-Requested-With"];
    //$httpProvider.defaults.headers.common['X-Requested-With'] = 'XMLHttpRequest';
    $tooltipProvider.options({
      appendToBody: true
    });
  })
  // angular-ui config
  .value('ui.config', {
    animate: 'ui-hide',
  })
  // split array displays separates an array inside a textarea with newlines
  .directive('splitArray', function() {
      return {
          restrict: 'A',
          require: 'ngModel',
          link: function(scope, element, attr, ngModel) {

              function fromUser(text) {
                  return text.split("\n");
              }

              function toUser(array) {                        
                  if (array) {
                    return array.join("\n");
                  }
              }

              ngModel.$parsers.push(fromUser);
              ngModel.$formatters.push(toUser);
          }
      };
  })
  .factory('ProxiedSites', ['$websocket', '$interval', '$window', '$rootScope', function($websocket, $interval, $window, $rootScope) {
      var dataStream = $websocket('ws://' + document.location.host + '/data');
      var WS_RECONNECT_INTERVAL = 5000;
      var WS_RETRY_COUNT = 0;

      dataStream.onMessage(function(message) {
          var msg = JSON.parse(message.data);
          console.log("Got proxiedsites msg", msg);

          if (!$rootScope.entries) {
            console.log("Initializing proxied sites entries", msg.Additions);
            $rootScope.entries = msg.Additions;
            $rootScope.originalList = msg.Additions;
          } else {
            var entries = $rootScope.entries.slice(0);
            if (msg.Additions) {
              entries = _.union(entries, msg.Additions);
            }
            if (msg.Deletions) {
              entries = _.difference(entries, msg.Deletions)
            }
            entries = _.compact(entries);
            entries.sort();

            console.log("About to set entries", entries);
            $rootScope.$apply(function() {
              console.log("Setting entries", entries);
              $rootScope.entries = entries;
              $rootScope.originalList = entries;  
            })
          }
      });

      dataStream.onOpen(function(msg) {
        $rootScope.wsConnected = true;
        WS_RETRY_COUNT = 0;
        $rootScope.backendIsGone = false;
        $rootScope.wsLastConnectedAt = new Date();
        console.log("New websocket instance created " + msg);
      });

      dataStream.onClose(function(msg) {
          $rootScope.wsConnected = false;
          // try to reconnect indefinitely
          // when the websocket closes
          $interval(function() {
              console.log("Trying to reconnect to disconnected websocket");
              dataStream = $websocket('ws://' + document.location.host + '/data');
              dataStream.onOpen(function(msg) {
                $window.location.reload();
              });
          }, WS_RECONNECT_INTERVAL);
          console.log("This websocket instance closed " + msg);
      });

      dataStream.onError(function(msg) {
          console.log("Error on this websocket instance " + msg);
      });

      var methods = {
          update: function() {
              dataStream.send(JSON.stringify($rootScope.updates));
          },
          get: function() {
              dataStream.send(JSON.stringify({ action: 'get' }));
          }
      };
      return methods;
  }])
  .run(function ($filter, $log, $rootScope, $timeout, $window, $websocket,
                 $translate, $http, apiSrvc, gaMgr, modelSrvc, ENUMS, EXTERNAL_URL, MODAL, CONTACT_FORM_MAXLEN) {

    var CONNECTIVITY = ENUMS.CONNECTIVITY,
        MODE = ENUMS.MODE,
        jsonFltr = $filter('json'),
        model = modelSrvc.model,
        prettyUserFltr = $filter('prettyUser'),
        reportedStateFltr = $filter('reportedState');

    // for easier inspection in the JavaScript console
    $window.rootScope = $rootScope;
    $window.model = model;

    $rootScope.EXTERNAL_URL = EXTERNAL_URL;

    $http.get('data/package.json').
      success(function(pkg, status, headers, config) {
      var version = pkg.version,
        components = version.split('.'),
        major = components[0],
        minor = components[1],
        patch = (components[2] || '').split('-')[0];
        $rootScope.lanternUiVersion = [major, minor, patch].join('.');
    }).error(function(data, status, headers, config) {
       console.log("Error retrieving UI version!");
    });

    $rootScope.model = model;
    $rootScope.DEFAULT_AVATAR_URL = 'img/default-avatar.png';
    $rootScope.CONTACT_FORM_MAXLEN = CONTACT_FORM_MAXLEN;

    angular.forEach(ENUMS, function(val, key) {
      $rootScope[key] = val;
    });

    $rootScope.reload = function () {
      location.reload(true); // true to bypass cache and force request to server
    };

    $rootScope.switchLang = function (lang) {
        $rootScope.lang = lang;
        $translate.use(lang);
    };

    $rootScope.changeLang = function(lang) {
      return $rootScope.interaction(INTERACTION.changeLang, {lang: lang});
    };

    $rootScope.openRouterConfig = function() {
      return $rootScope.interaction(INTERACTION.routerConfig);
    };

    $rootScope.openExternal = function(url) {
      return $window.open(url);
    };

    $rootScope.resetContactForm = function (scope) {
      if (scope.show) {
        var reportedState = jsonFltr(reportedStateFltr(model));
        scope.diagnosticInfo = reportedState;
      }
    };

    $rootScope.interactionWithNotify = function (interactionid, scope, reloadAfter) {
      var extra;
      if (scope.notify) {
        var diagnosticInfo = scope.diagnosticInfo;
        if (diagnosticInfo) {
          try {
            diagnosticInfo = angular.fromJson(diagnosticInfo);
          } catch (e) {
            $log.debug('JSON decode diagnosticInfo', diagnosticInfo, 'failed, passing as-is');
          }
        }
        extra = {
          context: model.modal,
          message: scope.message,
          diagnosticInfo: diagnosticInfo
        };
      }
      $rootScope.interaction(interactionid, extra).then(function () {
        if (reloadAfter) $rootScope.reload();
      });
    };

    $rootScope.backendIsGone = false;
    $rootScope.$watch("wsConnected", function(wsConnected) {
      var MILLIS_UNTIL_BACKEND_CONSIDERED_GONE = 10000;
      if (!wsConnected) {
        // In 11 seconds, check if we're still not connected
        $timeout(function() {
          var lastConnectedAt = $rootScope.wsLastConnectedAt;
          if (lastConnectedAt) {
            var timeSinceLastConnected = new Date().getTime() - lastConnectedAt.getTime();
            $log.debug("Time since last connect", timeSinceLastConnected);
            if (timeSinceLastConnected > MILLIS_UNTIL_BACKEND_CONSIDERED_GONE) {
              // If it's been more than 10 seconds since we last connect,
              // treat the backend as gone
              console.log("Backend is gone");
              $rootScope.backendIsGone = true;
            } else {
              $rootScope.backendIsGone = false;
            }
          }
        }, MILLIS_UNTIL_BACKEND_CONSIDERED_GONE + 1);
      }
    });
  });
