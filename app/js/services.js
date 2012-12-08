'use strict';

angular.module('app.services', [])
  // primitives wrapped in objects for mutatability
  .value('dev', {value: true}) // controls debug logging and developer panel
  .value('sanity', {value: true}) // triggers failure mode when false
  .constant('MODEL_SYNC_CHANNEL', '/sync')
  .constant('REQUIRED_VERSIONS', {
    modelSchema: {major: 0, minor: 0},
    httpApi: {major: 0, minor: 0},
    bayeuxProtocol: {major: 0, minor: 0}
  })
  .constant('VER', [0, 0, 1]) // frontend version XXX pull from package.json or some such?
  .constant('DEFAULT_AVATAR_URL', '/app/img/default-avatar.png')
  // enums
  .constant('EXTERNAL_URL', {
    helpTranslate: 'https://github.com/getlantern/lantern/wiki/Contributing#wiki-other-languages',
    httpsEverywhere: 'https://www.eff.org/https-everywhere'
  })
  .constant('INPUT_PATS', {
    // from http://html5pattern.com/
    DOMAIN: /^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,6}$/,
    IPV4: /((^|\.)((25[0-5])|(2[0-4]\d)|(1\d\d)|([1-9]?\d))){4}$/
  })
  // XXX use some kind of Object.fromkeys function
  .constant('SETTING', {
    lang: 'lang',
    mode: 'mode',
    autoReport: 'autoReport',
    autoStart: 'autoStart',
    systemProxy: 'systemProxy',
    proxyAllSites: 'proxyAllSites',
    proxyPort: 'proxyPort',
    proxiedSites: 'proxiedSites'
  })
  .constant('MODE', {
    give: 'give',
    get: 'get'
  })
  .constant('CONNECTIVITY', {
    notConnected: 'notConnected',
    connecting: 'connecting',
    connected: 'connected'
  })
  .constant('MODAL', {
    settingsLoadFailure: 'settingsLoadFailure',
    welcome: 'welcome',
    authorize: 'authorize',
    gtalkConnecting: 'gtalkConnecting',
    gtalkUnreachable: 'gtalkUnreachable',
    authorizeLater: 'authorizeLater',
    notInvited: 'notInvited',
    requestInvite: 'requestInvite',
    requestSent: 'requestSent',
    firstInviteReceived: 'firstInviteReceived',
    proxiedSites: 'proxiedSites',
    systemProxy: 'systemProxy',
    lanternFriends: 'lanternFriends',
    finished: 'finished',
    contactDevs: 'contactDevs',
    settings: 'settings',
    confirmReset: 'confirmReset',
    giveModeForbidden: 'giveModeForbidden',
    about: 'about',
    updateAvailable: 'updateAvailable',
    scenarios: 'scenarios',
    none: ''
  })
  .constant('INTERACTION', {
    lanternFriends: 'lanternFriends',
    contactDevs: 'contactDevs',
    settings: 'settings',
    reset: 'reset',
    proxiedSites: 'proxiedSites',
    about: 'about',
    updateAvailable: 'updateAvailable',
    requestInvite: 'requestInvite',
    retryNow: 'retryNow',
    retryLater: 'retryLater',
    cancel: 'cancel',
    continue: 'continue',
    close: 'close',
    quit: 'quit',
    scenarios: 'scenarios'
  })
  .service('ENUMS', function(MODE, CONNECTIVITY, MODAL, INTERACTION, SETTING, EXTERNAL_URL) {
    return {
      MODE: MODE,
      CONNECTIVITY: CONNECTIVITY,
      MODAL: MODAL,
      INTERACTION: INTERACTION,
      SETTING: SETTING,
      EXTERNAL_URL: EXTERNAL_URL
    };
  })
  // more flexible log service
  // https://groups.google.com/d/msg/angular/vgMF3i3Uq2Y/q1fY_iIvkhUJ
  .value('logWhiteList', /.*Ctrl|.*Srvc/)
  .factory('logFactory', function($log, dev, logWhiteList) {
    return function(prefix) {
      var match = prefix
        ? prefix.match(logWhiteList)
        : true;
      function extracted(prop) {
        if (!match) return angular.noop;
        return function() {
          var args = [].slice.call(arguments);
          prefix && args.unshift('[' + prefix + ']');
          $log[prop].apply($log, args);
        };
      }
      var logLogger = extracted('log');
      return {
        log:   logLogger,
        warn:  extracted('warn'),
        error: extracted('error'),
        debug: function() { if (dev.value) logLogger.apply(logLogger, arguments); }
      };
    }
  })
  .constant('COMETD_URL', location.protocol+'//'+location.host+'/cometd')
  .service('cometdSrvc', function(COMETD_URL, sanity, logFactory, $rootScope, $window) {
    var log = logFactory('cometdSrvc');
    // boilerplate cometd setup
    // http://cometd.org/documentation/cometd-javascript/subscription
    var cometd = $.cometd,
        connected = false,
        clientId,
        subscriptions = [];
    cometd.configure({
      url: COMETD_URL,
      backoffIncrement: 50,
      maxBackoff: 500,
      //logLevel: 'debug',
      // XXX necessary to work with Faye backend when browser lacks websockets:
      // https://groups.google.com/d/msg/faye-users/8cr_4QZ-7cU/sKVLbCFDkEUJ
      appendMessageTypeToURL: false
    });
    //cometd.websocketsEnabled = false; // XXX can we re-enable in Lantern?

    // http://cometd.org/documentation/cometd-javascript/subscription
    cometd.onListenerException = function(exception, subscriptionHandle, isListener, message) {
      log.error('Uncaught exception for subscription', subscriptionHandle, ':', exception, 'message:', message);
      if (isListener) {
        cometd.removeListener(subscriptionHandle);
        log.error('removed listener');
      } else {
        cometd.unsubscribe(subscriptionHandle);
        log.error('unsubscribed');
      }
      sanity.value = false;
    };

    cometd.addListener('/meta/connect', function(msg) {
      if (cometd.isDisconnected()) {
        connected = false;
        log.debug('connection closed');
        return;
      }
      var wasConnected = connected;
      connected = msg.successful;
      if (!wasConnected && connected) { // reconnected
        log.debug('connection established');
        $rootScope.$broadcast('cometdConnected');
        // XXX why do docs put this in successful handshake callback?
        cometd.batch(function(){ refresh(); });
      } else if (wasConnected && !connected) {
        log.warn('connection broken');
        $rootScope.$broadcast('cometdDisconnected');
      }
    });

    // backend doesn't send disconnects, but just in case
    cometd.addListener('/meta/disconnect', function(msg) {
      log.debug('got disconnect');
      if (msg.successful) {
        connected = false;
        log.debug('connection closed');
        $rootScope.$broadcast('cometdDisconnected');
        // XXX handle disconnect
      }
    });

    function subscribe(key) {
      if (connected) {
        key.sub = cometd.subscribe(key.chan, key.cb);
        log.debug('subscribed', key);
      } else {
        log.debug('queuing subscription request', key)
      }
      subscriptions.push(key);
      if (angular.isUndefined(key.renewOnReconnect))
        key.renewOnReconnect = true;
    }

    function unsubscribe(key) {
      cometd.unsubscribe(key.sub);
      log.debug('unsubscribed', key);
      key.renewOnReconnect = false;
    }

    function refresh() {
      log.debug('refreshing subscriptions');
      var renew = [];
      angular.forEach(subscriptions, function(key) {
        if (key.sub)
          cometd.unsubscribe(key.sub);
        if (key.renewOnReconnect)
          renew.push(key);
      });
      subscriptions = [];
      angular.forEach(renew, function(key) {
        subscribe(key);
      })
    }

    cometd.addListener('/meta/handshake', function(handshake) {
      if (handshake.successful) {
        log.debug('successful handshake', handshake);
        clientId = handshake.clientId;
        //cometd.batch(function(){ refresh(); }); // XXX moved to connect callback
      }
      else {
        log.warn('unsuccessful handshake');
        clientId = null;
      }
    });

    $($window).unload(function() {
      cometd.disconnect(true);
    });

    cometd.handshake();

    return {
      subscribe: subscribe,
      unsubscribe: unsubscribe,
      // for DevCtrl
      batch: function() { cometd.batch.apply(cometd, arguments); },
      publish: function(channel, data) { cometd.publish(channel, data); }
    };
  })
  /*
  .service('modelSchema', function(ENUMS) {...})
  .service('modelValidatorSrvc', function(modelSchema, logFactory) {...})
  */
  .service('modelSrvc', function($rootScope, MODEL_SYNC_CHANNEL, cometdSrvc, logFactory) {
    var log = logFactory('modelSrvc'),
        model = {},
        syncSubscriptionKey;

    function handleSync(msg) {
      // XXX use modelValidatorSrvc to validate update before accepting
      var data = msg.data, path = data.path, value = data.value;
      if (data.delete) {
        deleteByPath(model, path);
      } else {
        deleteByPath(model, path);
        merge(model, value, path);
      }
      $rootScope.$apply();
      log.debug('handleSync applied sync:\npath:', path || '""', '\nvalue:', value, '\ndelete:', data.delete);
    }

    syncSubscriptionKey = {chan: MODEL_SYNC_CHANNEL, cb: handleSync};
    cometdSrvc.subscribe(syncSubscriptionKey);

    return {
      model: model,
      // for SanityCtrl
      disconnect: function() {
          log.debug('disconnecting');
          cometdSrvc.unsubscribe(syncSubscriptionKey);
        }
    };
  })
  .service('apiSrvc', function(REQUIRED_VERSIONS) {
    var ver = REQUIRED_VERSIONS.httpApi.major + '.' +
              REQUIRED_VERSIONS.httpApi.minor;
    return {
      urlfor: function(endpoint, params) {
          var query = _.reduce(params, function(acc, val, key) {
              return acc+key+'='+encodeURIComponent(val)+'&';
            }, '?');
          return '/api/'+ver+'/'+endpoint+query;
        }
    };
  });
