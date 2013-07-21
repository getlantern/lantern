'use strict';

angular.module('app.i18n', [])
  .service('langSrvc', function(modelSrvc, getByPath, LANG, DEFAULT_LANG, DEFAULT_DIRECTION) {
    var model = modelSrvc.model;
    function lang() {
      return getByPath(model, '/settings/lang') ||
             getByPath(model, '/system/lang') ||
             DEFAULT_LANG;
    }
    function direction() {
      return (LANG[lang()] || {}).dir || DEFAULT_DIRECTION;
    }
    return {
      lang: lang,
      direction: direction
    };
  })
  .constant('TRANSLATIONS', {}) // XXX
  // https://groups.google.com/d/msg/angular/641c1ykOX4k/hcXI5HsSD5MJ
  .filter('i18n', function($filter, langSrvc, LANG, TRANSLATIONS, $http) {

    // XXX hack to populate TRANSLATIONS by loading json
    var fetched = false;
    _.forEach(LANG, function (langObj, langKey) {
      var url = './locale/'+langKey+'.json';
      $http.get(url).success(function (data) {
          TRANSLATIONS[langKey] = data;
          fetched = true;
        }).error(function () {
          console.error('Failed to load', url);
        });
    });

    var COUNT = /{}/g,
        numFltr = $filter('number');
    function keyNotFound(key) {
      return '(translation key "'+key+'" not found)';
    }
    function pluralNotFound(key, count) {
      return '(plural not found for key "'+key+'" and count "'+count+'")';
    }
    return function(key, count) {
      if (_.isUndefined(key)) return '(translation key undefined. did you forget quotes?)';
      if (!key) return '';
      if (!fetched) return ''; // XXX remove when hack above is removed
      if (!_.isUndefined(count)) {
        key += count === 1 ? '_1' : '_OTHER';
        var translation =
            (TRANSLATIONS[langSrvc.lang()] || {})[key] ||
            TRANSLATIONS[DEFAULT_LANG][key];
        if (translation) return translation.replace(COUNT, numFltr(count));
        return pluralNotFound(key, count);
      }
      var translation =
          (TRANSLATIONS[langSrvc.lang()] || {})[key] ||
          TRANSLATIONS[DEFAULT_LANG][key];
      if (!translation) return keyNotFound(key);
      return translation;
    };
  });
