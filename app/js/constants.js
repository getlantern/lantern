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

var DEFAULT_LANG = 'en',
    DEFAULT_DIRECTION = 'ltr',
    LANG = {
      en: {dir: 'ltr', name: 'English'}/*,
      zh: {dir: 'ltr', name: '中文'},
      fa: {dir: 'rtl', name: 'پارسی'},
      ar: {dir: 'rtl', name: 'العربية'}
      */
    },
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
      // HTML5 compatible email regex (http://www.whatwg.org/specs/web-apps/current-work/multipage/states-of-the-type-attribute.html)
      EMAIL: /^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$/,
      // from http://html5pattern.com/
      DOMAIN: /^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,6}$/,
      IPV4: /((^|\.)((25[0-5])|(2[0-4]\d)|(1\d\d)|([1-9]?\d))){4}$/
    },
    EXTERNAL_URL = {
      helpTranslate: 'https://github.com/getlantern/lantern/wiki/Contributing#wiki-other-languages',
      autoReportPrivacy: 'https://github.com/getlantern/lantern/wiki/Privacy#wiki-optional-information',
      httpsEverywhere: 'https://www.eff.org/https-everywhere'
    },
    // enums
    MODE = makeEnum(['give', 'get']),
    OS = makeEnum(['windows', 'linux', 'osx']),
    MODAL = makeEnum([
      'settingsLoadFailure',
      'unexpectedState', // frontend only
      'welcome',
      'authorize',
      'connecting',
      'notInvited',
      'proxiedSites',
      'systemProxy',
      'lanternFriends',
      'finished',
      'contact',
      'settings',
      'confirmReset',
      'giveModeForbidden',
      'about',
      'updateAvailable',
      'scenarios'],
      {none: ''}),
    INTERACTION = makeEnum([
      'give',
      'get',
      'set',
      'lanternFriends',
      'accept',
      'decline',
      'invite',
      'contact',
      'settings',
      'reset',
      'proxiedSites',
      'about',
      'updateAvailable',
      'retry',
      'cancel',
      'continue',
      'close',
      'quit',
      'refresh',
      'unexpectedStateReset',
      'unexpectedStateRefresh',
      'developer',
      'scenarios']),
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
    CONNECTIVITY = makeEnum([
      'notConnected',
      'connecting',
      'connected']),
    GTALK_STATUS = makeEnum([
      'offline',
      'unavailable',
      'idle',
      'available']),
    ENUMS = {
      MODE: MODE,
      OS: OS,
      MODAL: MODAL,
      INTERACTION: INTERACTION,
      SETTING: SETTING,
      PEER_TYPE: PEER_TYPE,
      CONNECTIVITY: CONNECTIVITY,
      GTALK_STATUS: GTALK_STATUS
    };

if (typeof angular == 'object' && angular && typeof angular.module == 'function') {
  angular.module('app.constants', [])
    .constant('DEFAULT_LANG', DEFAULT_LANG)
    .constant('DEFAULT_DIRECTION', DEFAULT_DIRECTION)
    .constant('LANG', LANG)
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
    .constant('CONNECTIVITY', CONNECTIVITY)
    .constant('GTALK_STATUS', GTALK_STATUS)
    // frontend-only
    .constant('LANTERNUI_VER', window.LANTERNUI_VER) // set in version.js
    .constant('REQUIRED_API_VER', REQUIRED_API_VER)
    .constant('API_URL_PREFIX', API_URL_PREFIX);
} else if (typeof exports == 'object' && exports && typeof module == 'object' && module && module.exports == exports) {
  module.exports = {
    DEFAULT_LANG: DEFAULT_LANG,
    DEFAULT_DIRECTION: DEFAULT_DIRECTION,
    LANG: LANG,
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
    CONNECTIVITY: CONNECTIVITY,
    GTALK_STATUS: GTALK_STATUS
  };
}
