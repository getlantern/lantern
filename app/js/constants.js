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
    COMETD_MOUNT_POINT = '/cometd',
    COMETD_URL = typeof location == 'object' ?
                   location.protocol+'//'+location.host+COMETD_MOUNT_POINT :
                   COMETD_MOUNT_POINT,
    MODEL_SYNC_CHANNEL = '/sync',
    DEFAULT_AVATAR_URL = '/app/img/default-avatar.png',
    INPUT_PATS = {
      // from http://html5pattern.com/
      DOMAIN: /^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,6}$/,
      IPV4: /((^|\.)((25[0-5])|(2[0-4]\d)|(1\d\d)|([1-9]?\d))){4}$/
    },
    EXTERNAL_URL = {
      helpTranslate: 'https://github.com/getlantern/lantern/wiki/Contributing#wiki-other-languages',
      httpsEverywhere: 'https://www.eff.org/https-everywhere'
    },
    // enums
    MODE = makeEnum(['give', 'get']),
    OS = makeEnum(['windows', 'linux', 'osx']),
    MODAL = makeEnum([
      'settingsLoadFailure',
      'welcome',
      'authorize',
      'gtalkConnecting',
      'gtalkUnreachable',
      'authorizeLater',
      'notInvited',
      'requestInvite',
      'requestSent',
      'firstInviteReceived',
      'proxiedSites',
      'systemProxy',
      'lanternFriends',
      'finished',
      'contactDevs',
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
      'contactDevs',
      'settings',
      'reset',
      'proxiedSites',
      'about',
      'updateAvailable',
      'requestInvite',
      'retryNow',
      'retryLater',
      'cancel',
      'continue',
      'close',
      'quit',
      'developer',
      'scenarios']),
    SETTING = makeEnum([
      'lang',
      'mode',
      'autoReport',
      'autoStart',
      'systemProxy',
      'proxyAllSites',
      'proxyPort',
      'proxiedSites']),
    CONNECTIVITY = makeEnum([
      'notConnected',
      'connecting',
      'connected']),
    GTALK_STATUS = makeEnum([
      'offline',
      'busy',
      'idle',
      'available']),
    ENUMS = {
      MODE: MODE,
      OS: OS,
      MODAL: MODAL,
      INTERACTION: INTERACTION,
      SETTING: SETTING,
      CONNECTIVITY: CONNECTIVITY,
      GTALK_STATUS: GTALK_STATUS
    };

if (typeof angular == 'object' && angular && typeof angular.module == 'function') {
  angular.module('app.constants', [])
    .constant('DEFAULT_LANG', DEFAULT_LANG)
    .constant('DEFAULT_DIRECTION', DEFAULT_DIRECTION)
    .constant('LANG', LANG)
    .constant('COMETD_MOUNT_POINT', COMETD_MOUNT_POINT)
    .constant('COMETD_URL', COMETD_URL)
    .constant('MODEL_SYNC_CHANNEL', MODEL_SYNC_CHANNEL)
    .constant('DEFAULT_AVATAR_URL', DEFAULT_AVATAR_URL)
    .constant('INPUT_PATS', INPUT_PATS)
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
    .constant('VER', [0, 0, 1]) // XXX pull from package.json or some such?
    .constant('REQUIRED_VERSIONS', {
      modelSchema: {major: 0, minor: 0},
      httpApi: {major: 0, minor: 0},
      bayeuxProtocol: {major: 0, minor: 0}
    });
} else if (typeof exports == 'object' && exports && typeof module == 'object' && module && module.exports == exports) {
  module.exports = {
    DEFAULT_LANG: DEFAULT_LANG,
    DEFAULT_DIRECTION: DEFAULT_DIRECTION,
    LANG: LANG,
    COMETD_MOUNT_POINT: COMETD_MOUNT_POINT,
    COMETD_URL: COMETD_URL,
    MODEL_SYNC_CHANNEL: MODEL_SYNC_CHANNEL,
    DEFAULT_AVATAR_URL: DEFAULT_AVATAR_URL,
    INPUT_PATS: INPUT_PATS,
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
