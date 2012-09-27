'use strict';

angular.module('app.i18n', [])
  .constant('defaultLang', 'en')
  .constant('translations', {
    en: {
      WAITINGFORLANTERN: 'Waiting for Lantern...'
    }
  });
