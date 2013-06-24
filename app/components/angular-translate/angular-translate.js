angular.module('pascalprecht.translate', ['ng']).run([
  '$translate',
  function ($translate) {
    var key = $translate.storageKey(), storage = $translate.storage();
    if (storage) {
      if (!storage.get(key)) {
        if (angular.isString($translate.preferredLanguage())) {
          $translate.uses($translate.preferredLanguage());
        } else {
          storage.set(key, $translate.uses());
        }
      } else {
        $translate.uses(storage.get(key));
      }
    } else if (angular.isString($translate.preferredLanguage())) {
      $translate.uses($translate.preferredLanguage());
    }
  }
]);
angular.module('pascalprecht.translate').constant('$STORAGE_KEY', 'NG_TRANSLATE_LANG_KEY');
angular.module('pascalprecht.translate').provider('$translate', [
  '$STORAGE_KEY',
  function ($STORAGE_KEY) {
    var $translationTable = {}, $preferredLanguage, $fallbackLanguage, $uses, $storageFactory, $storageKey = $STORAGE_KEY, $storagePrefix, $missingTranslationHandlerFactory, $loaderFactory, $loaderOptions, NESTED_OBJECT_DELIMITER = '.';
    var translations = function (langKey, translationTable) {
      if (!langKey && !translationTable) {
        return $translationTable;
      }
      if (langKey && !translationTable) {
        if (angular.isString(langKey)) {
          return $translationTable[langKey];
        } else {
          angular.extend($translationTable, flatObject(langKey));
        }
      } else {
        if (!angular.isObject($translationTable[langKey])) {
          $translationTable[langKey] = {};
        }
        angular.extend($translationTable[langKey], flatObject(translationTable));
      }
    };
    var flatObject = function (data, path, result) {
      var key, keyWithPath, val;
      if (!path) {
        path = [];
      }
      if (!result) {
        result = {};
      }
      for (key in data) {
        if (!data.hasOwnProperty(key))
          continue;
        val = data[key];
        if (angular.isObject(val)) {
          flatObject(val, path.concat(key), result);
        } else {
          keyWithPath = path.length ? '' + path.join(NESTED_OBJECT_DELIMITER) + NESTED_OBJECT_DELIMITER + key : key;
          result[keyWithPath] = val;
        }
      }
      return result;
    };
    this.translations = translations;
    this.preferredLanguage = function (langKey) {
      if (langKey) {
        $preferredLanguage = langKey;
      } else {
        return $preferredLanguage;
      }
    };
    this.fallbackLanguage = function (langKey) {
      if (langKey) {
        $fallbackLanguage = langKey;
      } else {
        return $fallbackLanguage;
      }
    };
    this.uses = function (langKey) {
      if (langKey) {
        if (!$translationTable[langKey] && !$loaderFactory) {
          throw new Error('$translateProvider couldn\'t find translationTable for langKey: \'' + langKey + '\'');
        }
        $uses = langKey;
      } else {
        return $uses;
      }
    };
    var storageKey = function (key) {
      if (!key) {
        if ($storagePrefix) {
          return $storagePrefix + $storageKey;
        }
        return $storageKey;
      }
      $storageKey = key;
    };
    this.storageKey = storageKey;
    this.useUrlLoader = function (url) {
      this.useLoader('$translateUrlLoader', { url: url });
    };
    this.useStaticFilesLoader = function (options) {
      this.useLoader('$translateStaticFilesLoader', options);
    };
    this.useLoader = function (loaderFactory, options) {
      $loaderFactory = loaderFactory;
      $loaderOptions = options || {};
    };
    this.useLocalStorage = function () {
      this.useStorage('$translateLocalStorage');
    };
    this.useCookieStorage = function () {
      this.useStorage('$translateCookieStorage');
    };
    this.useStorage = function (storageFactory) {
      $storageFactory = storageFactory;
    };
    this.storagePrefix = function (prefix) {
      if (!prefix) {
        return prefix;
      }
      $storagePrefix = prefix;
    };
    this.useMissingTranslationHandlerLog = function () {
      this.useMissingTranslationHandler('$translateMissingTranslationHandlerLog');
    };
    this.useMissingTranslationHandler = function (factory) {
      $missingTranslationHandlerFactory = factory;
    };
    this.$get = [
      '$interpolate',
      '$log',
      '$injector',
      '$rootScope',
      '$q',
      function ($interpolate, $log, $injector, $rootScope, $q) {
        var Storage, pendingLoader = false;
        if ($storageFactory) {
          Storage = $injector.get($storageFactory);
          if (!Storage.get || !Storage.set) {
            throw new Error('Couldn\'t use storage \'' + $storageFactory + '\', missing get() or set() method!');
          }
        }
        var $translate = function (translationId, interpolateParams) {
          var table = $uses ? $translationTable[$uses] : $translationTable;
          if (table && table.hasOwnProperty(translationId)) {
            return $interpolate(table[translationId])(interpolateParams);
          }
          if ($missingTranslationHandlerFactory && !pendingLoader) {
            $injector.get($missingTranslationHandlerFactory)(translationId);
          }
          if ($uses && $fallbackLanguage && $uses !== $fallbackLanguage) {
            var translation = $translationTable[$fallbackLanguage][translationId];
            if (translation) {
              return $interpolate(translation)(interpolateParams);
            }
          }
          return translationId;
        };
        $translate.preferredLanguage = function () {
          return $preferredLanguage;
        };
        $translate.fallbackLanguage = function () {
          return $fallbackLanguage;
        };
        $translate.storage = function () {
          return Storage;
        };
        $translate.uses = function (key) {
          if (!key) {
            return $uses;
          }
          var deferred = $q.defer();
          if (!$translationTable[key]) {
            pendingLoader = true;
            $injector.get($loaderFactory)(angular.extend($loaderOptions, { key: key })).then(function (data) {
              var translationTable = {};
              if (angular.isArray(data)) {
                angular.forEach(data, function (table) {
                  angular.extend(translationTable, table);
                });
              } else {
                angular.extend(translationTable, data);
              }
              translations(key, translationTable);
              $uses = key;
              if ($storageFactory) {
                Storage.set($translate.storageKey(), $uses);
              }
              pendingLoader = false;
              $rootScope.$broadcast('translationChangeSuccess');
              deferred.resolve($uses);
            }, function (key) {
              $rootScope.$broadcast('translationChangeError');
              deferred.reject(key);
            });
            return deferred.promise;
          }
          $uses = key;
          if ($storageFactory) {
            Storage.set($translate.storageKey(), $uses);
          }
          deferred.resolve($uses);
          $rootScope.$broadcast('translationChangeSuccess');
          return deferred.promise;
        };
        $translate.storageKey = function () {
          return storageKey();
        };
        if ($loaderFactory && angular.equals($translationTable, {})) {
          $translate.uses($translate.uses());
        }
        return $translate;
      }
    ];
  }
]);
angular.module('pascalprecht.translate').directive('translate', [
  '$filter',
  '$interpolate',
  function ($filter, $interpolate) {
    var translate = $filter('translate');
    return {
      restrict: 'A',
      scope: true,
      link: function linkFn(scope, element, attr) {
        attr.$observe('translate', function (translationId) {
          if (angular.equals(translationId, '')) {
            scope.translationId = $interpolate(element.text().replace(/^\s+|\s+$/g, ''))(scope.$parent);
          } else {
            scope.translationId = translationId;
          }
        });
        attr.$observe('values', function (interpolateParams) {
          scope.interpolateParams = interpolateParams;
        });
        scope.$on('translationChangeSuccess', function () {
          element.html(translate(scope.translationId, scope.interpolateParams));
        });
        scope.$watch('translationId + interpolateParams', function (nValue) {
          if (nValue) {
            element.html(translate(scope.translationId, scope.interpolateParams));
          }
        });
      }
    };
  }
]);
angular.module('pascalprecht.translate').filter('translate', [
  '$parse',
  '$translate',
  function ($parse, $translate) {
    return function (translationId, interpolateParams) {
      if (!angular.isObject(interpolateParams)) {
        interpolateParams = $parse(interpolateParams)();
      }
      return $translate(translationId, interpolateParams);
    };
  }
]);