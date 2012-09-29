'use strict';

angular.module('app.i18n', [])
  .constant('defaultLang', 'en')
  .constant('translations', {
    en: {
      WAITING_FOR_LANTERN: 'Waiting for Lantern...',
      UNEXPECTED_STATE_TITLE: 'Unexpected State',
      UNEXPECTED_STATE_PROMPT: 'The application is in an unexpected state. You can try refreshing, restarting Lantern, or resetting your settings if it happens again.',
      RESET: 'Reset',
      REFRESH: 'Refresh',
      UNLOCK_SETTINGS_TITLE: 'Unlock Settings',
      UNLOCK_SETTINGS_PROMPT: 'Enter your Lantern password to unlock your settings.',
      PASSWORD: 'password',
      PASSWORD_CONFIRM: 'confirm password',
      SET: 'Set',
      PASSWORDS_MUST_MATCH: 'Passwords must match',
      PASSWORD_INVALID: 'Password invalid',
      UNLOCK: 'Unlock',
      COULDNOTLOAD_SETTINGS_TITLE: 'Couldn’t Load Settings',
      COULDNOTLOAD_SETTINGS_PROMPT: 'Your settings could not be loaded and may be corrupt. Choose Reset to make a backup and then start over, or choose Quit to try to resolve the problem later.', // XXX we currently don't back up settings before wiping them
      NOTIFY_LANTERN_DEVS: 'Notify Lantern developers',
      UNEXPECTED_ERROR: 'An unexpected error has occurred.',
      QUIT: 'Quit',
      SETPASSWORD_TITLE: 'Set Password',
      SETPASSWORD_PROMPT: 'Set your Lantern password so your information can be stored securely.',
    }
  });
