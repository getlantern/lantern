'use strict';

angular.module('app.filters', [])
  // basic i18n filter
  // @see https://groups.google.com/d/msg/angular/641c1ykOX4k/hcXI5HsSD5MJ
  .filter('i18n', function(syncedModel, defaultLang, translations) {
    return function(key) {
      var lang = syncedModel.connected() ?
                 syncedModel.model.settings.lang :
                 defaultLang;
      return translations[lang][key] ||
             translations[defaultLang][key] ||
             '(translation key "'+key+'" not found)';
    }
  });
