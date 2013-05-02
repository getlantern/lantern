'use strict';

angular.module('app.services', [])
  // more flexible log service
  // https://groups.google.com/d/msg/angular/vgMF3i3Uq2Y/q1fY_iIvkhUJ
  .value('logWhiteList', /.*Ctrl|.*Srvc/)
  .factory('logFactory', function($log, logWhiteList, state) {
    return function(prefix) {
      var match = prefix ? prefix.match(logWhiteList) : true;
      function extracted(prop) {
        if (!match) return angular.noop;
        return function() {
          var args = [].slice.call(arguments);
          if (prefix) args.unshift('[' + prefix + ']');
          $log[prop].apply($log, args);
        };
      }
      var logLogger = extracted('log');
      return {
        log:   logLogger,
        warn:  extracted('warn'),
        error: extracted('error'),
        // XXX angular now has support for console.debug?
        debug: function() { if (state.dev) logLogger.apply(logLogger, arguments); }
      };
    };
  })
  .service('cometdSrvc', function(COMETD_URL, logFactory, apiSrvc, $rootScope, $window) {
    var log = logFactory('cometdSrvc');
    // boilerplate cometd setup
    // http://cometd.org/documentation/cometd-javascript/subscription
    var cometd = $.cometd,
        connected = false,
        clientId,
        subscriptions = [];
    cometd.configure({
      url: COMETD_URL,
      //logLevel: 'debug',
      backoffIncrement: 100,
      maxBackoff: 500,
      // necessary to work with Faye backend when browser lacks websockets:
      // https://groups.google.com/d/msg/faye-users/8cr_4QZ-7cU/sKVLbCFDkEUJ
      appendMessageTypeToURL: false
    });
    //cometd.websocketsEnabled = false; // XXX can we re-enable in Lantern?

    function disconnect() {
      cometd.disconnect(true);
    }
    $($window).unload(disconnect);

    // http://cometd.org/documentation/cometd-javascript/subscription
    cometd.onListenerException = function(exception, subscriptionHandle, isListener, message) {
      log.error('Uncaught exception for subscription', subscriptionHandle, ':', exception, 'message:', message);
      apiSrvc.exception({error: 'uncaughtSubscriptionException', subscriptionHandle: subscriptionHandle, exception: exception, message: message});
      if (isListener) {
        cometd.removeListener(subscriptionHandle);
        log.error('removed listener');
      } else {
        cometd.unsubscribe(subscriptionHandle);
        log.error('unsubscribed');
      }
      disconnect();
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
        log.debug('queuing subscription request', key);
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
      _.each(renew, function(key) {
        subscribe(key);
      });
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


    cometd.handshake();

    return {
      subscribe: subscribe,
      unsubscribe: unsubscribe,
      disconnect: disconnect
    };
  })
  .service('modelSrvc', function($rootScope, apiSrvc, MODEL_SYNC_CHANNEL, cometdSrvc, logFactory) {
    var log = logFactory('modelSrvc'),
        model = {},
        syncSubscriptionKey;

    // XXX use modelValidatorSrvc to validate update before accepting
    function handleSync(msg) {
      var patch = msg.data;
      // backend can send updates before model has been populated
      // https://github.com/getlantern/lantern/issues/587
      if (patch[0].path !== '' && _.isEmpty(model)) {
        log.debug('ignoring', msg, 'while model has not yet been populated');
        return;
      }
      $rootScope.$apply(function() {
        if (patch[0].path === '') {
          // XXX jsonpatch can't mutate root object https://github.com/dharmafly/jsonpatch.js/issues/10
          angular.copy(patch[0].value, model);
        } else {
          try {
            applyPatch(model, patch);
          } catch (e) {
            if (!(e instanceof PatchApplyError || e instanceof InvalidPatch)) throw e;
            log.error('Error applying patch', patch);
            apiSrvc.exception({exception: e, patch: patch});
          }
        }
      });
    }

    syncSubscriptionKey = {chan: MODEL_SYNC_CHANNEL, cb: handleSync};
    cometdSrvc.subscribe(syncSubscriptionKey);

    return {
      model: model,
      sane: true
    };
  })
  // XXX shared global state object
  .service('state', function() {
    return {};
  })
  .service('apiSrvc', function($http, API_URL_PREFIX) {
    return {
      exception: function(data) {
        return $http.post(API_URL_PREFIX+'/exception', data);
      },
      interaction: function(interactionid, data) {
        var url = API_URL_PREFIX+'/interaction/'+interactionid;
        return $http.post(url, data);
      }
    };
  });
