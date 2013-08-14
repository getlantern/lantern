'use strict';

angular.module('app.i18n', [])
  .constant('TRANSLATIONS', {}) // populated lazily via ajax
  .run(function ($http, $log, $rootScope, LANGS, DEFAULT_LANG, TRANSLATIONS, modelSrvc, getByPath) {
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
    });

    function maybeChangeLang(lang) {
      var closest = closestAvailableLang(lang);
      if (closest) {
        $rootScope.lang = closest;
        if (!TRANSLATIONS[closest]) {
          loadTranslationsFor(closest);
        }
      }
    }

    function closestAvailableLang(lang) {
      for (var lang_ in LANGS) {
        if (lang === lang_ || lang === lang_.substring(0, 2)) {
          return lang_;
        }
      }
      return null;
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
    return function (key, count) {
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
        return translation.replace(COUNT, numFltr(count));
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
