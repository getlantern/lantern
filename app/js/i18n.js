'use strict';

angular.module('app.i18n', [])
  .constant('defaultLang', 'en')
  .constant('translations', {
    en: {
      WAITING_FOR_LANTERN: 'Waiting for Lantern...',
      UNLOCK_SETTINGS_TITLE: 'Unlock Settings',
      UNLOCK_SETTINGS_PROMPT: 'Enter your Lantern password to unlock your settings.',
      PASSWORD: 'password',
      PASSWORD_INVALID: 'Password invalid',
      UNLOCK: 'Unlock'
    }
  });
