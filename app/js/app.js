'use strict';

var app = angular.module('app', [
  'app.constants',
  'app.helpers',
  'pascalprecht.translate',
  'app.filters',
  'app.services',
  'app.directives',
  'app.vis',
  'ngSanitize',
  'ui.utils',
  'ui.showhide',
  'ui.select2',
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
  .service('modalService', function () {
    this.Data = {
        modal: 'none'
    };
    this.getAll = function () {
        return this.Data;
    };
    this.setModal = function (val) {
        this.Data.modal = val;
    };
  })
  .config(function($tooltipProvider, $httpProvider, $translateProvider, DEFAULT_LANG) {

      $translateProvider.preferredLanguage(DEFAULT_LANG);

      $translateProvider.useStaticFilesLoader({
          prefix: './locale/',
          suffix: '.json'
      });
    // Add the X-Requested-With header back in when we configure http provider; otherwise, making POST requests doesn't work
    // version 1.1.* and above of AngularJS dropped this default behavior
    // see here for related info http://django-angular.readthedocs.org/en/latest/integration.html
    $httpProvider.defaults.headers.common['X-Requested-With'] = 'XMLHttpRequest';
    $tooltipProvider.options({
      appendToBody: true
    });
  })
  // angular-ui config
  .value('ui.config', {
    animate: 'ui-hide',
  })
  .run(function ($filter, $log, $rootScope, $timeout, $window, 
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
      if ($rootScope.mockBackend) {
        return $window.open(url);
      } else {
        return $rootScope.interaction(INTERACTION.url, {url: url});
      }
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

  });
