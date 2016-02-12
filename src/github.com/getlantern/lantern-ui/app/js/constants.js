'use strict';

function makeEnum(keys, extra) {
  var obj = {};
  for (var i=0, key=keys[i]; key; key=keys[++i]) {
    obj[key] = key;
  }
  if (extra) {
    for (var key in extra)
      obj[key] = extra[key];
  }
  return obj;
}

var DEFAULT_LANG = 'en_US',
    DEFAULT_DIRECTION = 'ltr',
    LANGS = {
      // http://www.omniglot.com/language/names.htm
      en_US: {dir: 'ltr', name: 'English'},
      de: {dir: 'ltr', name: 'Deutsch'},
      fr_FR: {dir: 'ltr', name: 'français (France)'},
      fr_CA: {dir: 'ltr', name: 'français (Canada)'},
      ca: {dir: 'ltr', name: 'català'},
      pt_BR: {dir: 'ltr', name: 'português'},
      fa_IR: {dir: 'rtl', name: 'پارسی'},
      zh_CN: {dir: 'ltr', name: '中文'},
      nl: {dir: 'ltr', name: 'Nederlands'},
      sk: {dir: 'ltr', name: 'slovenčina'},
      cs: {dir: 'ltr', name: 'čeština'},
      sv: {dir: 'ltr', name: 'Svenska'},
      ja: {dir: 'ltr', name: '日本語'},
      uk: {dir: 'ltr', name: 'Українська (діаспора)'},
      uk_UA: {dir: 'ltr', name: 'Українська (Україна)'},
      ru_RU: {dir: 'ltr', name: 'Русский язык'},
      es: {dir: 'ltr', name: 'español'},
      ar: {dir: 'rtl', name: 'العربية'}
    },
    GOOGLE_ANALYTICS_WEBPROP_ID = 'UA-21815217-13',
    GOOGLE_ANALYTICS_DISABLE_KEY = 'ga-disable-'+GOOGLE_ANALYTICS_WEBPROP_ID,
    loc = typeof location == 'object' ? location : undefined,
    // this allows the real backend to mount the entire app under a random path
    // for security while the mock backend can always use '/app':
    APP_MOUNT_POINT = loc ? loc.pathname.split('/')[1] : 'app',
    API_MOUNT_POINT = 'api',
    COMETD_MOUNT_POINT = 'cometd',
    COMETD_URL = loc && loc.protocol+'//'+loc.host+'/'+APP_MOUNT_POINT+'/'+COMETD_MOUNT_POINT,
    REQUIRED_API_VER = {major: 0, minor: 0}, // api version required by frontend
    REQ_VER_STR = [REQUIRED_API_VER.major, REQUIRED_API_VER.minor].join('.'),
    API_URL_PREFIX = ['', APP_MOUNT_POINT, API_MOUNT_POINT, REQ_VER_STR].join('/'),
    MODEL_SYNC_CHANNEL = '/sync',
    CONTACT_FORM_MAXLEN = 500000,
    INPUT_PAT = {
      // based on http://www.regular-expressions.info/email.html
      EMAIL: /^[a-zA-Z0-9._%+-]+@(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$/,
      EMAIL_INSIDE: /[a-zA-Z0-9._%+-]+@(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}/,
      // from http://html5pattern.com/
      DOMAIN: /^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,6}$/,
      IPV4: /((^|\.)((25[0-5])|(2[0-4]\d)|(1\d\d)|([1-9]?\d))){4}$/
    },
    EXTERNAL_URL = {
      rally: 'https://rally.org/lantern/donate',
      cloudServers: 'https://github.com/getlantern/lantern/wiki/Lantern-Cloud-Servers',
      autoReportPrivacy: 'https://github.com/getlantern/lantern/wiki/Privacy#wiki-optional-information',
      homepage: 'https://www.getlantern.org/',
      userForums: {
        en_US: 'https://groups.google.com/group/lantern-users-en',
        fr_FR: 'https://groups.google.com/group/lantern-users-fr',
        fr_CA: 'https://groups.google.com/group/lantern-users-fr',
        ar: 'https://groups.google.com/group/lantern-users-ar',
        fa_IR: 'https://groups.google.com/group/lantern-users-fa',
        zh_CN: 'https://lanternforum.greatfire.org/'
      },
      docs: 'https://github.com/getlantern/lantern/wiki',
      getInvolved: 'https://github.com/getlantern/lantern/wiki/Get-Involved',
      proxiedSitesWiki: 'https://github.com/getlantern/lantern-proxied-sites-lists/wiki',
      developers: 'https://github.com/getlantern/lantern'
    },
    // enums
    MODE = makeEnum(['give', 'get', 'unknown']),
    OS = makeEnum(['windows', 'linux', 'osx']),
    MODAL = makeEnum([
      'settingsLoadFailure',
      'unexpectedState', // frontend only
      'welcome',
      'authorize',
      'connecting',
      'notInvited',
      'proxiedSites',
      'lanternFriends',
      'finished',
      'contact',
      'settings',
      'confirmReset',
      'giveModeForbidden',
      'about',
      'sponsor',
      'sponsorToContinue',
      'updateAvailable',
      'scenarios'],
      {none: ''}),
    INTERACTION = makeEnum([
      'changeLang',
      'give',
      'get',
      'set',
      'lanternFriends',
      'friend',
      'reject',
      'contact',
      'settings',
      'reset',
      'proxiedSites',
      'about',
      'sponsor',
      'updateAvailable',
      'retry',
      'cancel',
      'continue',
      'close',
      'quit',
      'refresh',
      'unexpectedStateReset',
      'unexpectedStateRefresh',
      'url',
      'developer',
      'scenarios',
      'routerConfig']),
    SETTING = makeEnum([
      'lang',
      'mode',
      'autoReport',
      'runAtSystemStart',
      'systemProxy',
      'proxyAllSites',
      'proxyPort',
      'proxiedSites']),
    PEER_TYPE = makeEnum([
      'pc',
      'cloud',
      'laeproxy'
      ]),
    FRIEND_STATUS = makeEnum([
      'friend',
      'pending',
      'rejected'
      ]),
    CONNECTIVITY = makeEnum([
      'notConnected',
      'connecting',
      'connected']),
    GTALK_STATUS = makeEnum([
      'offline',
      'unavailable',
      'idle',
      'available']),
    SUGGESTION_REASON = makeEnum([
      'runningLantern',
      'friendedYou'
      ]),
    ENUMS = {
      MODE: MODE,
      OS: OS,
      MODAL: MODAL,
      INTERACTION: INTERACTION,
      SETTING: SETTING,
      PEER_TYPE: PEER_TYPE,
      FRIEND_STATUS: FRIEND_STATUS,
      CONNECTIVITY: CONNECTIVITY,
      GTALK_STATUS: GTALK_STATUS,
      SUGGESTION_REASON: SUGGESTION_REASON
    };

if (typeof angular == 'object' && angular && typeof angular.module == 'function') {
  angular.module('app.constants', [])
    .constant('DEFAULT_LANG', DEFAULT_LANG)
    .constant('DEFAULT_DIRECTION', DEFAULT_DIRECTION)
    .constant('LANGS', LANGS)
    .constant('API_MOUNT_POINT', API_MOUNT_POINT)
    .constant('APP_MOUNT_POINT', APP_MOUNT_POINT)
    .constant('COMETD_MOUNT_POINT', COMETD_MOUNT_POINT)
    .constant('COMETD_URL', COMETD_URL)
    .constant('MODEL_SYNC_CHANNEL', MODEL_SYNC_CHANNEL)
    .constant('CONTACT_FORM_MAXLEN', CONTACT_FORM_MAXLEN)
    .constant('INPUT_PAT', INPUT_PAT)
    .constant('EXTERNAL_URL', EXTERNAL_URL)
    .constant('ENUMS', ENUMS)
    .constant('MODE', MODE)
    .constant('OS', OS)
    .constant('MODAL', MODAL)
    .constant('INTERACTION', INTERACTION)
    .constant('SETTING', SETTING)
    .constant('PEER_TYPE', PEER_TYPE)
    .constant('FRIEND_STATUS', FRIEND_STATUS)
    .constant('CONNECTIVITY', CONNECTIVITY)
    .constant('GTALK_STATUS', GTALK_STATUS)
    .constant('SUGGESTION_REASON', SUGGESTION_REASON)
    // frontend-only
    .constant('GOOGLE_ANALYTICS_WEBPROP_ID', GOOGLE_ANALYTICS_WEBPROP_ID)
    .constant('GOOGLE_ANALYTICS_DISABLE_KEY', GOOGLE_ANALYTICS_DISABLE_KEY)
    .constant('LANTERNUI_VER', window.LANTERNUI_VER) // set in version.js
    .constant('REQUIRED_API_VER', REQUIRED_API_VER)
    .constant('BUILD_REVISION', LANTERN_BUILD_REVISION)
    .constant('API_URL_PREFIX', API_URL_PREFIX);
} else if (typeof exports == 'object' && exports && typeof module == 'object' && module && module.exports == exports) {
  module.exports = {
    DEFAULT_LANG: DEFAULT_LANG,
    DEFAULT_DIRECTION: DEFAULT_DIRECTION,
    LANGS: LANGS,
    API_MOUNT_POINT: API_MOUNT_POINT,
    APP_MOUNT_POINT: APP_MOUNT_POINT,
    COMETD_MOUNT_POINT: COMETD_MOUNT_POINT,
    COMETD_URL: COMETD_URL,
    MODEL_SYNC_CHANNEL: MODEL_SYNC_CHANNEL,
    CONTACT_FORM_MAXLEN: CONTACT_FORM_MAXLEN,
    INPUT_PAT: INPUT_PAT,
    EXTERNAL_URL: EXTERNAL_URL,
    ENUMS: ENUMS,
    MODE: MODE,
    OS: OS,
    MODAL: MODAL,
    INTERACTION: INTERACTION,
    SETTING: SETTING,
    PEER_TYPE: PEER_TYPE,
    FRIEND_STATUS: FRIEND_STATUS,
    CONNECTIVITY: CONNECTIVITY,
    GTALK_STATUS: GTALK_STATUS,
    SUGGESTION_REASON: SUGGESTION_REASON
  };
}
