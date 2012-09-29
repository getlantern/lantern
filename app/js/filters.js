'use strict';

angular.module('app.filters', [])
  // basic i18n filter
  // @see https://groups.google.com/d/msg/angular/641c1ykOX4k/hcXI5HsSD5MJ
  .filter('i18n', function(modelSrvc, defaultLang, translations) {
    return function(key) {
      if (!key) return '';
      var lang = (modelSrvc.model.settings || {}).lang ||
                 modelSrvc.model.lang ||
                 defaultLang;
      return translations[lang][key] ||
             translations[defaultLang][key] ||
             '(translation key "'+key+'" not found)';
    }
  });
