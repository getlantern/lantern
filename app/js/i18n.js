'use strict';

angular.module('app.i18n', [])
  .constant('TRANSLATIONS', {}) // populated lazily via ajax
  .run(function ($http, $log, $rootScope, LANGS, DEFAULT_LANG, EXTERNAL_URL, TRANSLATIONS, modelSrvc, getByPath) {
    var model = modelSrvc.model;

    $rootScope.LANGS = LANGS;
    $rootScope.lang = DEFAULT_LANG;
    loadTranslationsFor(DEFAULT_LANG);

    $rootScope.$watch('model.settings.lang', function (lang) {
      if (!lang) return;
      maybeChangeLang(lang);
    });

    $rootScope.$watch('model.system.lang', function (lang) {
      if (!lang || model.settings.lang) return;
      maybeChangeLang(lang);
    });

    $rootScope.$watch('lang', function (lang) {
      $rootScope.langDirection = LANGS[lang].dir;
      $rootScope.rtl = $rootScope.langDirection === 'rtl';
      var closest = closestAvailableLang(lang, EXTERNAL_URL.userForums);
    });

    $rootScope.valByLang = function (mapping) {
      return mapping[$rootScope.lang] || mapping[DEFAULT_LANG];
    };

    function maybeChangeLang(lang) {
      var closest = closestAvailableLang(lang);
      if (closest) {
        $rootScope.lang = closest;
        if (!TRANSLATIONS[closest]) {
          loadTranslationsFor(closest);
        }
      }
    }

    function closestAvailableLang(lang, keysObj) {
      keysObj = keysObj || LANGS;
      var bestMatch = null;
      for (var lang_ in keysObj) {
        if (lang === lang_) {
          return lang_;
        }
        if (lang.substring(0, 2) === lang_.substring(0, 2)) {
          bestMatch = lang_;
        }
      }
      return bestMatch;
    }

    function loadTranslationsFor(lang) {
      var url = './locale/'+lang+'.json';
      $http.get(url)
        .success(function (data) {
          TRANSLATIONS[lang] = data;
        })
        .error(function () {
          $log.error('Failed to load', url);
        });
    }
  })
  .filter('i18n', function ($filter, $log, $rootScope, TRANSLATIONS) {
    var COUNT = /{}/g,
        numFltr = $filter('number');
    return function (key, count, nonNegative) {
      if (!key) {
        if (_.isUndefined(key)) {
          $log.debug('translation key undefined. did you forget quotes?');
        }
        return '';
      }
      var lang = $rootScope.lang;
      if (!lang || !TRANSLATIONS[lang]) {
        // model lang fields or TRANSLATIONS not yet populated
        return '';
      }
      // XXX handle plurals better
      var pluralKeyExists = !_.isUndefined(TRANSLATIONS[lang][key+'_1']);
      if (pluralKeyExists) {
        if (_.isUndefined(count)) {
          //$log.debug('interpreted key', key, 'as plural but count undefined');
          return '';
        }
        key += count === 1 ? '_1' : '_OTHER';
        var translation = (TRANSLATIONS[lang] || {})[key];
        if (!translation) {
          if (TRANSLATIONS[DEFAULT_LANG]) {
            translation = TRANSLATIONS[DEFAULT_LANG][key];
          }
        }
        if (!translation) {
          $log.debug('plural not found for key "'+key+'" and count "'+count+'"');
          return '';
        }
        return translation.replace(COUNT, numFltr(nonNegative ? Math.max(count, 0) : count));
      }
      var translation = (TRANSLATIONS[lang] || {})[key];
      if (!translation) {
        if (TRANSLATIONS[DEFAULT_LANG]) {
          translation = TRANSLATIONS[DEFAULT_LANG][key];
        }
      }
      if (!translation) {
        if (TRANSLATIONS[lang]) {
          if (_.isUndefined(translation)) {
            $log.debug('translation key "'+key+'" not found');
          } else {
            $log.debug('translation missing for key "'+key+'" in lang', lang);
          }
        }
        return '';
      }
      return translation;
    };
  });
