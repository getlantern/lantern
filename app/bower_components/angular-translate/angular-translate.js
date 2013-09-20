/**
 * angular-translate - v1.1.0 - 2013-09-02
 * http://github.com/PascalPrecht/angular-translate
 * Copyright (c) 2013 ; Licensed 
 */
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
angular.module('pascalprecht.translate').provider('$translate', [
  '$STORAGE_KEY',
  function ($STORAGE_KEY) {
    var $translationTable = {}, $preferredLanguage, $fallbackLanguage, $uses, $nextLang, $storageFactory, $storageKey = $STORAGE_KEY, $storagePrefix, $missingTranslationHandlerFactory, $interpolationFactory, $interpolatorFactories = [], $loaderFactory, $loaderOptions, $notFoundIndicatorLeft, $notFoundIndicatorRight, NESTED_OBJECT_DELIMITER = '.';
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
      return this;
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
    this.addInterpolation = function (factory) {
      $interpolatorFactories.push(factory);
      return this;
    };
    this.useMessageFormatInterpolation = function () {
      return this.useInterpolation('$translateMessageFormatInterpolation');
    };
    this.useInterpolation = function (factory) {
      $interpolationFactory = factory;
      return this;
    };
    this.preferredLanguage = function (langKey) {
      if (langKey) {
        $preferredLanguage = langKey;
        return this;
      } else {
        return $preferredLanguage;
      }
    };
    this.translationNotFoundIndicator = function (indicator) {
      this.translationNotFoundIndicatorLeft(indicator);
      this.translationNotFoundIndicatorRight(indicator);
      return this;
    };
    this.translationNotFoundIndicatorLeft = function (indicator) {
      if (!indicator) {
        return $notFoundIndicatorLeft;
      }
      $notFoundIndicatorLeft = indicator;
      return this;
    };
    this.translationNotFoundIndicatorRight = function (indicator) {
      if (!indicator) {
        return $notFoundIndicatorRight;
      }
      $notFoundIndicatorRight = indicator;
      return this;
    };
    this.fallbackLanguage = function (langKey) {
      if (langKey) {
        $fallbackLanguage = langKey;
        return this;
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
        return this;
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
      return this.useLoader('$translateUrlLoader', { url: url });
    };
    this.useStaticFilesLoader = function (options) {
      return this.useLoader('$translateStaticFilesLoader', options);
    };
    this.useLoader = function (loaderFactory, options) {
      $loaderFactory = loaderFactory;
      $loaderOptions = options || {};
      return this;
    };
    this.useLocalStorage = function () {
      return this.useStorage('$translateLocalStorage');
    };
    this.useCookieStorage = function () {
      return this.useStorage('$translateCookieStorage');
    };
    this.useStorage = function (storageFactory) {
      $storageFactory = storageFactory;
      return this;
    };
    this.storagePrefix = function (prefix) {
      if (!prefix) {
        return prefix;
      }
      $storagePrefix = prefix;
      return this;
    };
    this.useMissingTranslationHandlerLog = function () {
      return this.useMissingTranslationHandler('$translateMissingTranslationHandlerLog');
    };
    this.useMissingTranslationHandler = function (factory) {
      $missingTranslationHandlerFactory = factory;
      return this;
    };
    this.$get = [
      '$log',
      '$injector',
      '$rootScope',
      '$q',
      function ($log, $injector, $rootScope, $q) {
        var Storage, defaultInterpolator = $injector.get($interpolationFactory || '$translateDefaultInterpolation'), pendingLoader = false, interpolatorHashMap = {};
        var loadAsync = function (key) {
          if (!key) {
            throw 'No language key specified for loading.';
          }
          var deferred = $q.defer();
          $rootScope.$broadcast('$translateLoadingStart');
          pendingLoader = true;
          $nextLang = key;
          $injector.get($loaderFactory)(angular.extend($loaderOptions, { key: key })).then(function (data) {
            $rootScope.$broadcast('$translateLoadingSuccess');
            var translationTable = {};
            if (angular.isArray(data)) {
              angular.forEach(data, function (table) {
                angular.extend(translationTable, table);
              });
            } else {
              angular.extend(translationTable, data);
            }
            translations(key, translationTable);
            pendingLoader = false;
            $nextLang = undefined;
            deferred.resolve(key);
            $rootScope.$broadcast('$translateLoadingEnd');
          }, function (key) {
            $rootScope.$broadcast('$translateLoadingError');
            deferred.reject(key);
            $nextLang = undefined;
            $rootScope.$broadcast('$translateLoadingEnd');
          });
          return deferred.promise;
        };
        if ($storageFactory) {
          Storage = $injector.get($storageFactory);
          if (!Storage.get || !Storage.set) {
            throw new Error('Couldn\'t use storage \'' + $storageFactory + '\', missing get() or set() method!');
          }
        }
        if ($interpolatorFactories.length > 0) {
          angular.forEach($interpolatorFactories, function (interpolatorFactory) {
            var interpolator = $injector.get(interpolatorFactory);
            interpolator.setLocale($preferredLanguage || $uses);
            interpolatorHashMap[interpolator.getInterpolationIdentifier()] = interpolator;
          });
        }
        var $translate = function (translationId, interpolateParams, interpolationId) {
          var table = $uses ? $translationTable[$uses] : $translationTable, Interpolator = interpolationId ? interpolatorHashMap[interpolationId] : defaultInterpolator;
          if (table && table.hasOwnProperty(translationId)) {
            return Interpolator.interpolate(table[translationId], interpolateParams);
          }
          if ($missingTranslationHandlerFactory && !pendingLoader) {
            $injector.get($missingTranslationHandlerFactory)(translationId, $uses);
          }
          if ($uses && $fallbackLanguage && $uses !== $fallbackLanguage) {
            var translation = $translationTable[$fallbackLanguage][translationId];
            if (translation) {
              var returnVal;
              Interpolator.setLocale($fallbackLanguage);
              returnVal = Interpolator.interpolate(translation, interpolateParams);
              Interpolator.setLocale($uses);
              return returnVal;
            }
          }
          if ($notFoundIndicatorLeft) {
            translationId = [
              $notFoundIndicatorLeft,
              translationId
            ].join(' ');
          }
          if ($notFoundIndicatorRight) {
            translationId = [
              translationId,
              $notFoundIndicatorRight
            ].join(' ');
          }
          return translationId;
        };
        $translate.preferredLanguage = function () {
          return $preferredLanguage;
        };
        $translate.fallbackLanguage = function () {
          return $fallbackLanguage;
        };
        $translate.proposedLanguage = function () {
          return $nextLang;
        };
        $translate.storage = function () {
          return Storage;
        };
        $translate.uses = function (key) {
          if (!key) {
            return $uses;
          }
          var deferred = $q.defer();
          $rootScope.$broadcast('$translateChangeStart');
          function useLanguage(key) {
            $uses = key;
            $rootScope.$broadcast('$translateChangeSuccess');
            if ($storageFactory) {
              Storage.set($translate.storageKey(), $uses);
            }
            defaultInterpolator.setLocale($uses);
            angular.forEach(interpolatorHashMap, function (interpolator, id) {
              interpolatorHashMap[id].setLocale($uses);
            });
            deferred.resolve(key);
            $rootScope.$broadcast('$translateChangeEnd');
          }
          if (!$translationTable[key] && $loaderFactory) {
            loadAsync(key).then(useLanguage, function (key) {
              $rootScope.$broadcast('$translateChangeError');
              deferred.reject(key);
              $rootScope.$broadcast('$translateChangeEnd');
            });
          } else {
            useLanguage(key);
          }
          return deferred.promise;
        };
        $translate.storageKey = function () {
          return storageKey();
        };
        $translate.refresh = function (langKey) {
          var deferred = $q.defer();
          function onLoadSuccess() {
            deferred.resolve();
            $rootScope.$broadcast('$translateRefreshEnd');
          }
          function onLoadFailure() {
            deferred.reject();
            $rootScope.$broadcast('$translateRefreshEnd');
          }
          if (!$loaderFactory) {
            throw new Error('Couldn\'t refresh translation table, no loader registered!');
          }
          if (!langKey) {
            $rootScope.$broadcast('$translateRefreshStart');
            for (var lang in $translationTable) {
              if ($translationTable.hasOwnProperty(lang)) {
                delete $translationTable[lang];
              }
            }
            var loaders = [];
            if ($fallbackLanguage) {
              loaders.push(loadAsync($fallbackLanguage));
            }
            if ($uses) {
              loaders.push($translate.uses($uses));
            }
            if (loaders.length > 0) {
              $q.all(loaders).then(onLoadSuccess, onLoadFailure);
            } else
              onLoadSuccess();
          } else if ($translationTable.hasOwnProperty(langKey)) {
            $rootScope.$broadcast('$translateRefreshStart');
            delete $translationTable[langKey];
            var loader = null;
            if (langKey === $uses) {
              loader = $translate.uses($uses);
            } else {
              loader = loadAsync(langKey);
            }
            loader.then(onLoadSuccess, onLoadFailure);
          } else
            deferred.reject();
          return deferred.promise;
        };
        if ($loaderFactory) {
          if (angular.equals($translationTable, {})) {
            $translate.uses($translate.uses());
          }
          if ($fallbackLanguage && !$translationTable[$fallbackLanguage]) {
            loadAsync($fallbackLanguage);
          }
        }
        return $translate;
      }
    ];
  }
]);
angular.module('pascalprecht.translate').factory('$translateDefaultInterpolation', [
  '$interpolate',
  function ($interpolate) {
    var $translateInterpolator = {}, $locale, $identifier = 'default';
    $translateInterpolator.setLocale = function (locale) {
      $locale = locale;
    };
    $translateInterpolator.getInterpolationIdentifier = function () {
      return $identifier;
    };
    $translateInterpolator.interpolate = function (string, interpolateParams) {
      return $interpolate(string)(interpolateParams);
    };
    return $translateInterpolator;
  }
]);
angular.module('pascalprecht.translate').constant('$STORAGE_KEY', 'NG_TRANSLATE_LANG_KEY');
angular.module('pascalprecht.translate').directive('translate', [
  '$filter',
  '$interpolate',
  function ($filter, $interpolate) {
    var translate = $filter('translate');
    return {
      restrict: 'AE',
      scope: true,
      link: function linkFn(scope, element, attr) {
        if (attr.translateInterpolation) {
          scope.interpolation = attr.translateInterpolation;
        }
        attr.$observe('translate', function (translationId) {
          if (angular.equals(translationId, '') || translationId === undefined) {
            scope.translationId = $interpolate(element.text().replace(/^\s+|\s+$/g, ''))(scope.$parent);
          } else {
            scope.translationId = translationId;
          }
        });
        attr.$observe('translateValues', function (interpolateParams) {
          scope.interpolateParams = interpolateParams;
        });
        scope.$on('$translateChangeSuccess', function () {
          element.html(translate(scope.translationId, scope.interpolateParams, scope.interpolation));
        });
        scope.$watch('translationId + interpolateParams', function (nValue) {
          if (nValue) {
            element.html(translate(scope.translationId, scope.interpolateParams, scope.interpolation));
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
    return function (translationId, interpolateParams, interpolation) {
      if (!angular.isObject(interpolateParams)) {
        interpolateParams = $parse(interpolateParams)();
      }
      return $translate(translationId, interpolateParams, interpolation);
    };
  }
]);