'use strict';

angular.module('app.i18n', [])
  .constant('DEFAULTLANG', 'en')
  .constant('NBSP', ' ') // unicode no-break space
  .service('langSrvc', function(modelSrvc, DEFAULTLANG, LANGDIRECTIONS) {
    var DEFAULTDIRECTION = 'ltr';
    function lang() {
      return modelSrvc.get('settings.lang') ||
             modelSrvc.get('lang') ||
             DEFAULTLANG;
    }
    function direction() {
      return LANGDIRECTIONS[lang()] || DEFAULTDIRECTION;
    }
    return {
      lang: lang,
      direction: direction
    };
  })
  .constant('LANGDIRECTIONS', {
    en: 'ltr',
    zh: 'ltr',
    fa: 'rtl',
    ar: 'rtl'
  })
  .constant('TRANSLATIONS', {
    zh: {
      WELCOME_TITLE: '欢迎到Lantern',
      WELCOME_PROMPT: '互联网为每个人的自由。',
      GIVE_ACCESS: '给访问',
      GET_ACCESS: '进入'
    },
    fa: {
      WELCOME_TITLE: '‫به انجمن خوش آمدید ‬‪Lantern‬',
      WELCOME_PROMPT: '‫آزادی اینترنت برای همه.‬',
      GIVE_ACCESS: '‫دسترسی‬',
      GET_ACCESS: '‫دسترسی‬'
    },
    ar: {
      WELCOME_TITLE: '‫مرحبا بكم في ‬‪Lantern‬',
      WELCOME_PROMPT: '‫حرية الإنترنت للجميع.‬',
      GIVE_ACCESS: '‫منح حق الوصول‬',
      GET_ACCESS: '‫احصل على دخول‬'
    },
    en: {
      WAITING_FOR_LANTERN: 'Waiting for Lantern...',
      UNEXPECTED_STATE_TITLE: 'Unexpected State',
      UNEXPECTED_STATE_PROMPT: 'The application is in an unexpected state. You can try refreshing, restarting Lantern, or resetting your settings if it happens again.',
      RESET: 'Reset',
      REFRESH: 'Refresh',
      SETTINGS_UNLOCK_TITLE: 'Unlock Settings',
      SETTINGS_UNLOCK_PROMPT: 'Enter your Lantern password to unlock your settings.',
      PASSWORD: 'password',
      PASSWORD_CONFIRM: 'confirm password',
      CREATE: 'Create',
      CREATED: 'Created',
      PASSWORDS_MUST_MATCH: 'Passwords must match',
      PASSWORD_INVALID: 'Password invalid',
      UNLOCK: 'Unlock',
      UNLOCKED: 'Unlocked',
      SETTINGS_LOAD_FAILURE_TITLE: 'Couldn’t Load Settings',
      SETTINGS_LOAD_FAILURE_PROMPT: 'Your settings could not be loaded and may be corrupt. Choose Reset to make a backup and then start over, or choose Quit to try to resolve the problem later.', // XXX we currently don't back up settings before wiping them
      NOTIFY_LANTERN_DEVS: 'Notify Lantern developers',
      UNEXPECTED_ERROR: 'An unexpected error has occurred.',
      ERROR: 'An error has occurred.',
      QUIT: 'Quit',
      PASSWORD_CREATE_TITLE: 'Create Password',
      PASSWORD_CREATE_PROMPT: 'Create your Lantern password so your information can be stored securely.',
      WELCOME_TITLE: 'Welcome to Lantern',
      WELCOME_PROMPT: 'Internet freedom for everyone.',
      GIVE_ACCESS: 'Give Access',
      GET_ACCESS: 'Get Access',
      SIGNIN_TITLE: 'Sign in to Google Talk',
      SIGNIN_PROMPT: 'Lantern connects users around the world together in a trust network. Signing in to Google Talk allows you to connect through users you know, and not just anyone.',
      HELP: 'Help',
      SIGNIN_TIP_GTALK: 'If you have a Gmail account, you already have Google Talk. Your Google Talk userid is the same as your Gmail address. If you don’t, you can create one at google.com.',
      SIGNIN_TIP_SECURE: 'Your Google password is sent over a secure connection and is used only to sign in to Google Talk.',
      SIGNIN_TIP_SAVE_PASSWORD: 'Securely save your password in Lantern’s encrypted settings file.',
      SIGNIN_STATUS_BAD_CREDENTIALS: 'Invalid user and password combination',
      SIGNIN_STATUS_NOT_AUTHORIZED: 'User does not have Lantern access.',
      SIGNIN_STATUS_SERVICE_UNAVAILABLE: 'Could not connect to Google Talk.',
      GTALK_USERID: 'Google Talk userid',
      EMAIL_PLACEHOLDER: 'email@example.com',
      GTALK_PASSWORD: 'Google Talk password',
      SAVE_PASSWORD: 'Save password',
      PASSWORD_SAVED: 'password saved',
      START_OVER: 'Start over',
      CANCEL: 'Cancel',
      SIGN_IN: 'Sign in',
      SIGNING_IN: 'Signing in...',
      SIGNED_IN: 'Signed in',
      CONTINUE: 'Continue',
      CONFIGURING: 'Configuring...',
      GTALK_UNREACHABLE_TITLE: 'Could not connect to Google Talk',
      GTALK_UNREACHABLE_PROMPT: 'Lantern could not connect to Google Talk. If you are not connected to the internet, please connect and try again. Lantern can also keep trying to connect for you until a connection is established.',
      RETRY_NOW: 'Retry now',
      RETRY_LATER: 'Retry later',
      NOT_INVITED_TITLE: 'User Not Recognized',
      NOT_INVITED_PROMPT: 'The user you entered has not been invited to join Lantern yet.',
      TRY_ANOTHER_USER: 'Try another user',
      REQUEST_INVITE: 'Request invite',
      REQUEST_INVITE_TITLE: 'Request Invite',
      REQUEST_INVITE_PROMPT: 'Request an invitation from:',
      SOMEONE_I_KNOW_LABEL: 'Someone I know using Lantern',
      SOMEONE_I_KNOW_INFO: 'If your contact is a recognized user, he or she will receive a message immediately with the content of your request.',
      LANTERN_DEVS_LABEL: 'The Lantern developers',
      LANTERN_DEVS_INFO: 'New users will be invited as fast as the network can accommodate them.',
      SEND_REQUEST: 'Send request',
      SENDING_REQUEST: 'Sending request...',
      REQUEST_SENT_TITLE: 'Request sent',
      REQUEST_SENT_PROMPT: 'Your request has been sent. You will receive an email when you have been invited. You can continue to use Lantern in demonstration mode in the meantime.',
      FIRST_INVITE_RECEIVED_TITLE: 'Invitation Received!',
      FIRST_INVITE_RECEIVED_INTRO: 'You have received an invitation to join Lantern!',
      FIRST_INVITE_RECEIVED_SENDER: 'The sender of this invitation was:',
      FIRST_INVITE_RECEIVED_PROMPT: 'You will now be able to complete Lantern setup.',
      SYSTEM_PROXY_TITLE: 'System Proxy',
      SYSTEM_PROXY_PROMPT: 'Lantern can be configured as your system proxy so your browser will use it automatically.',
      SYSTEM_PROXY_TRUE: 'Set Lantern as my system proxy (recommended)',
      SYSTEM_PROXY_TRUE_INFO: 'You may be prompted for an administrator password.',
      SYSTEM_PROXY_FALSE: 'I will manually configure my browser to use Lantern.',
      SYSTEM_PROXY_FALSE_INFO: 'Lantern’s HTTP proxy runs on port 8787.', // XXX don't hardcode
      SYSTEM_PROXY_ERROR: 'Proxy configuration failed',
      FINISHED_TITLE: 'Finished!',
      FINISHED_PROMPT: 'Thank you for joining Lantern. Your participation at this early stage is invaluable.',
      AUTOREPORT_PROMPT: 'Securely report diagnostics and anonymous usage statistics to contribute to Lantern.', // XXX link to more info?
      AUTOREPORT_ENABLE: 'Enable automatic reporting',
      FINISH: 'Finish',
      SIGNIN_DISCOVER_PROXIES_PROMPT: 'Lantern can connect to known proxies but will be unable to discover new ones until signed in to Google Talk.',
      SETTINGS: 'Settings',
      MODE: 'Mode',
      PROXY: 'Proxy',
      MANAGE_PROXIED_SITES: 'Manage proxied sites...',
      HTTPS_EVERYWHERE_LABEL: 'For your security, http requests will automatically be converted to https requests using rulesets from HTTPS Everywhere',
      ADVANCED: 'Advanced',
      CARET_COLLAPSED: '▸',
      CARET_EXPANDED: '▾',
      PROXY_ALL_TRAFFIC: 'Proxy all traffic (not recommended)',
      PORT: 'Port',
      APP: 'App',
      SAVE_GTALK_PASSWORD: 'Securely save Google Talk password',
      START_AT_LOGIN: 'Run Lantern automatically on startup',
      SET_AS_SYSTEM_PROXY: 'Set as system proxy (recommended)',
      NO_AUTOREPORT_WARNING: 'Your usage will not contribute to global totals',
      RESET_LANTERN: 'Reset Lantern',
      CLOSE: 'Close'
    }
  })
  // https://groups.google.com/d/msg/angular/641c1ykOX4k/hcXI5HsSD5MJ
  .filter('i18n', function(langSrvc, DEFAULTLANG, TRANSLATIONS, NBSP) {
    return function(key, nbsp) {
      if (typeof key == 'undefined') return '(translation key undefined. did you forget quotes?)';
      if (!key) return '';
      var translation =
          (TRANSLATIONS[langSrvc.lang()] || {})[key] ||
          TRANSLATIONS[DEFAULTLANG][key] ||
          '(translation key "'+key+'" not found)';
      return nbsp ? translation.replace(/ /g, NBSP) : translation;
    }
  });
