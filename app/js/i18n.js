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
      UNLOCK: 'Unlock',
      CORRUPT_SETTINGS_TITLE: 'Corrupt Settings',
      CORRUPT_SETTINGS_PROMPT: 'Your settings could not be loaded and may be corrupt. Choose Reset to make a backup and then start over, or choose quit to try to resolve the problem later.', // XXX we currently don't back up settings before wiping them
      NOTIFY_LANTERN_DEVS: 'Notify Lantern developers',
      UNEXPECTED_ERROR: 'An unexpected error has occurred.',
      RESET: 'Reset',
      QUIT: 'Quit'
    }
  });
