'use strict';

angular.module('app.i18n', [])
  .constant('DEFAULTLANG', 'en')
  .constant('NBSP', ' ') // unicode no-break space
  .service('langSrvc', function(modelSrvc, DEFAULTLANG, LANGDIRECTIONS) {
    var DEFAULTDIRECTION = 'ltr';
    function lang() {
      return modelSrvc.get('settings.lang') ||
             modelSrvc.get('system.lang') ||
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
      HELP_TRANSLATE: 'Help translate',
      LANGUAGE: 'Language',
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
      SETTINGS_LOAD_FAILURE_PROMPT: 'Your settings could not be loaded and may be corrupt. Choose Reset to make a backup and then start over, or choose Quit to try again later.', // XXX we currently don't back up settings before wiping them
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
      AUTHORIZE_TITLE: 'Authorize Lantern to Access Your Google Talk Account',
      AUTHORIZE_PROMPT: 'Click below to be taken to google.com to give Lantern access to your Google Talk account.',
      AUTHORIZE_TIP_GTALK: 'Lantern works best with a large network of users who trust one another to share internet connections. Authorizing Lantern to access your Google Talk account allows you to connect on Lantern through users you know, and not just anyone.',
      HELP: 'Help',
      WHY: 'Why?',
      AUTHORIZE_LANTERN: 'Authorize Lantern',
      EMAIL_PLACEHOLDER: 'email@example.com',
      CANCEL: 'Cancel',
      CONTINUE: 'Continue',
      UPDATING: 'Updating...',
      CONFIGURING: 'Configuring...',
      CONNECTING: 'Connecting...',
      CONNECTED: 'Connected',
      GTALK_CONNECTING_TITLE: 'Connecting to Google Talk',
      GTALK_UNREACHABLE_TITLE: 'Could not connect to Google Talk',
      GTALK_UNREACHABLE_PROMPT: 'Lantern could not connect to Google Talk. If you are not connected to the internet, please connect and try again. Lantern can also keep trying to connect for you until a connection is established.',
      RETRY_NOW: 'Retry now',
      RETRY_LATER: 'Retry later',
      NOT_INVITED_TITLE: 'User Not Invited',
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
      REQUEST_SENT_TITLE: 'Request Sent',
      REQUEST_SENT_PROMPT: 'Your request has been sent. You will receive an email when you have been invited. You can continue to use Lantern in demonstration mode in the meantime.', // XXX can't send email if we only store hashes of emails
      FIRST_INVITE_RECEIVED_TITLE: 'Invitation Received!',
      FIRST_INVITE_RECEIVED_INTRO: 'You have received an invitation to join Lantern!',
      FIRST_INVITE_RECEIVED_SENDER: 'The sender of this invitation was:',
      FIRST_INVITE_RECEIVED_PROMPT: 'You will now be able to complete Lantern setup.',
      AUTHORIZE_LATER_TITLE: 'Authorize Later',
      AUTHORIZE_LATER_PROMPT: 'Lantern will keep trying to reach Google and prompt you to authorize again when it becomes available. You can continue to use Lantern in demonstration mode in the meantime.',
      PROXIED_SITES_TITLE: 'Proxied Sites',
      CONFIGURE_PROXIED_SITES: 'Choose proxied sites:',
      PROXIED_SITES_PROMPT: 'By default, Lantern only proxies your traffic to certain sites. Sites that you don’t need to proxy will be accessed directly, saving time and resources.',
      PROXIED_SITES_TIP: 'Content on other sites included in pages on these sites will also be proxied automatically.',
      ERROR_INVALID_LINE: 'Invalid line:',
      ERROR_MAX_PROXIED_SITES_EXCEEDED: 'Maximum number of proxied sites exceeded',
      SYSTEM_PROXY_TITLE: 'System Proxy',
      SYSTEM_PROXY_PROMPT: 'Lantern can be configured as your system proxy so your browser will use it automatically.',
      SYSTEM_PROXY_TRUE: 'Set Lantern as my system proxy (recommended)',
      ADMIN_PW_PROMPT: 'You may be prompted for an administrator password.',
      SYSTEM_PROXY_FALSE: 'I will manually configure my browser to use Lantern.',
      HTTP_PROXY_PORT: 'Lantern’s HTTP proxy runs on port', // XXX interpolate the variable
      SYSTEM_PROXY_ERROR: 'Proxy configuration failed',
      FINISHED_TITLE: 'Finished!',
      FINISHED_PROMPT: 'Thank you for joining Lantern. Your participation at this early stage is invaluable.',
      AUTOREPORT_PROMPT: 'Securely report diagnostics and anonymous usage statistics to contribute to Lantern.', // XXX link to more info?
      AUTOREPORT_ENABLE: 'Enable automatic reporting',
      FINISH: 'Finish',
      INVITE_FRIENDS_TITLE: 'Lantern Friends',
      INVITE_FRIENDS_INTRO: 'Lantern relies on a large network of users who trust one another to share internet connections. Inviting people you trust to join Lantern helps Lantern work better.',
      NO_INVITES: 'You currently have no invites.',
      MORE_INVITES: 'You will receive more invites as you continue to run Lantern.',
      INVITE_FRIENDS_PROMPT: 'Enter some contacts to invite:',
      AUTOTRUSTED_PROMPT: 'Lantern users in your Google Talk contacts will be trusted already.',
      AUTOTRUSTED_LABEL: 'Lantern friends:',
      NONE_RUNNING_LANTERN: 'None of your Google Talk contacts are part of Lantern yet.',
      INVITES_REMAINING: 'invite(s) remaining', // XXX ng-pluralize
      SETTINGS: 'Settings',
      MODE: 'Mode',
      PROXY: 'Proxy',
      MANAGE_PROXIED_SITES: 'Manage proxied sites...',
      //HTTPS_EVERYWHERE_LABEL: 'For your security, http requests to this site will automatically be converted to https requests using rulesets from HTTPS Everywhere.',
      ADVANCED: 'Advanced',
      SHOW_IN_DOCK: 'Show in dock', // XXX taskbar if windows
      CARET_COLLAPSED: '▸',
      CARET_EXPANDED: '▾',
      PROXY_ALL_TRAFFIC: 'Proxy all traffic (not recommended)',
      PORT: 'Port',
      APP: 'App',
      SAVE_GTALK_PASSWORD: 'Securely save Google Talk password',
      AUTO_START: 'Run Lantern automatically on startup',
      SET_AS_SYSTEM_PROXY: 'Set as system proxy (recommended)',
      NO_AUTOREPORT_WARNING: 'Your usage will not contribute to global totals',
      ENABLE_AUTOREPORT_SUGGESTION: 'Enable automatic reporting in Settings to have your usage contribute to global totals',
      RESET_ELLIPSIS: 'Reset...',
      CLOSE: 'Close',
      BACK: 'Back',
      ABOUT_TITLE: 'About Lantern',
      UPDATE_AVAILABLE_TITLE: 'Update Available',
      CONTACT_DEVS_TITLE: 'Contact Lantern Developers',
      CONTACT_DEVS_PROMPT: '...',
      GIVE_MODE_FORBIDDEN_TITLE: 'Give Access Mode Forbidden',
      GIVE_MODE_FORBIDDEN_PROMPT: 'Your internet connection appears to be coming from a censoring country. Giving access through this connection could be undesirable for other users. You can run Lantern in Give Access mode if you connect to the internet from outside a censoring country.', // XXX say which country and source identifying it as censoring
      CONTINUE_IN_GET_MODE: 'Continue in Get Access Mode',
      CONFIRM_RESET_TITLE: 'Confirm Reset',
      CONFIRM_RESET_PROMPT: 'Resetting Lantern will clear all saved information since it was set up.',
      BUG_REPORT_PROMPT: 'Additional information describing what happened'
    }
  })
  // https://groups.google.com/d/msg/angular/641c1ykOX4k/hcXI5HsSD5MJ
  .filter('i18n', function(langSrvc, DEFAULTLANG, TRANSLATIONS) {
    return function(key) {
      if (typeof key == 'undefined') return '(translation key undefined. did you forget quotes?)';
      if (!key) return '';
      var translation =
          (TRANSLATIONS[langSrvc.lang()] || {})[key] ||
          TRANSLATIONS[DEFAULTLANG][key] ||
          '(translation key "'+key+'" not found)';
      return translation;
    }
  });
