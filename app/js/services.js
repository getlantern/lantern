'use strict';

angular.module('app.services', [])
  // more flexible log service
  // https://groups.google.com/d/msg/angular/vgMF3i3Uq2Y/q1fY_iIvkhUJ
  .value('logWhiteList', /.*Ctrl|.*Srvc|.*Mgr/)
  .factory('logFactory', function($log, $window, logWhiteList) {
    // XXX can take out on upgrade to angular 1.1 which added $log.debug
    if (!$log.debug) {
      var console = $window.console || {},
          logFn = console.debug || console.log || angular.noop;
      if (logFn.apply) {
        $log.debug = function () { return logFn.apply(console, arguments); };
      } else {
        $log.debug = function (arg1, arg2) { logFn(arg1, arg2); };
      }
    }
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
      return {
        log:   extracted('log'),
        warn:  extracted('warn'),
        error: extracted('error'),
        debug: extracted('debug')
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
      if (connected) {
        $rootScope.cometdLastConnectedAt = new Date();
      }
      if (!wasConnected && connected) { // reconnected
        log.debug('connection established');
        $rootScope.$apply(function () {
          $rootScope.cometdConnected = true;
        });
        // XXX why do docs put this in successful handshake callback?
        cometd.batch(function(){ refresh(); });
      } else if (wasConnected && !connected) {
        log.warn('connection broken');
        $rootScope.$apply(function () {
          $rootScope.cometdConnected = false;
        });
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
  .service('modelSrvc', function($rootScope, apiSrvc, MODEL_SYNC_CHANNEL, cometdSrvc, logFactory, flashlightStats) {
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
      try {
        $rootScope.$apply(function() {
          if (patch[0].path === '') {
            // XXX jsonpatch can't mutate root object https://github.com/dharmafly/jsonpatch.js/issues/10
            angular.copy(patch[0].value, model);
          } else {
            try {
              applyPatch(model, patch);
              for (var i=0; i<patch.length; i++) {
                if (patch[i].path == "/instanceStats") {
                  // Remember the rate we got from the update as the "lanternRate".
                  // This is later summed with the flashlight rate to update
                  // the total rate.
                  patch[0].value.allBytes.lanternRate = patch[0].value.allBytes.rate;
                  break;
                }
              }
            } catch (e) {
              if (!(e instanceof PatchApplyError || e instanceof InvalidPatch)) throw e;
              log.error('Error applying patch', patch);
              apiSrvc.exception({exception: e, patch: patch});
            }
          }
          flashlightStats.updateModel(model);
        });
      } catch (e) {
        // XXX https://github.com/angular/angular.js/issues/2602
        // XXX https://github.com/angular-ui/bootstrap/issues/407
        if (/scrollHeight/.test(e.message)) {
          log.debug('Swallowing "<TTL> $digest() iterations reached" error caused by https://github.com/angular-ui/bootstrap/issues/407');
        } else {
          throw e;
        }
      }
    }

    syncSubscriptionKey = {chan: MODEL_SYNC_CHANNEL, cb: handleSync};
    cometdSrvc.subscribe(syncSubscriptionKey);

    return {
      model: model,
      sane: true
    };
  })
  .service('gaMgr', function ($window, GOOGLE_ANALYTICS_DISABLE_KEY, GOOGLE_ANALYTICS_WEBPROP_ID, logFactory, modelSrvc) {
    var log = logFactory('gaMgr'),
        model = modelSrvc.model,
        ga = $window.ga;

    function stopTracking() {
      log.debug('disabling analytics');
      //trackPageView('end'); // force the current session to end with this hit
      $window[GOOGLE_ANALYTICS_DISABLE_KEY] = true;
    }

    function startTracking() {
      log.debug('enabling analytics');
      $window[GOOGLE_ANALYTICS_DISABLE_KEY] = false;
      trackPageView('start');
    }

    // start out with google analytics disabled
    // https://developers.google.com/analytics/devguides/collection/analyticsjs/advanced#optout
    stopTracking();

    // but get a tracker set up and ready for use if analytics become enabled
    // https://developers.google.com/analytics/devguides/collection/analyticsjs/field-reference
    ga('create', GOOGLE_ANALYTICS_WEBPROP_ID, {cookieDomain: 'none'});
    ga('set', {
      anonymizeIp: true,
      forceSSL: true,
      location: 'http://lantern-ui/',
      hostname: 'lantern-ui',
      title: 'lantern-ui'
    });

    function trackPageView(sessionControl) {
      var page = model.modal || '/';
      ga('set', 'page', page);
      ga('send', 'pageview', sessionControl ? {sessionControl: sessionControl} : undefined);
      log.debug(sessionControl === 'end' ? 'sent analytics session end' : 'tracked pageview', 'page =', page);
    }

    return {
      stopTracking: stopTracking,
      startTracking: startTracking,
      trackPageView: trackPageView
    };
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
  })
  .service('flashlightStats', function ($window, $log) {
    // This service grabs stats from flashlight and adds them to the standard
    // model.
    var flashlightPeers = {};

    // connect() starts listening for peer updates
    function connect() {
      var source = new EventSource('http://127.0.0.1:15670/');
      source.addEventListener('message', function(e) {
        var data = JSON.parse(e.data);
        if (data.type == "peer") {
          var peer = data.data;
          flashlightPeers[peer.peerid] = peer;
        }
      }, false);
  
      source.addEventListener('open', function(e) {
        $log.debug("flashlight connection opened");
      }, false);
  
      source.addEventListener('error', function(e) {
        if (e.readyState == EventSource.CLOSED) {
          $log.debug("flashlight connection closed");
        }
      }, false);
    }
    
    // updateModel updates a model that doesn't include flashlight peers with
    // information about the flashlight peers, including updating aggregated
    // figures like total bps.
    function updateModel(model) {
      var flashlightRate = 0;
      for (var peerid in flashlightPeers) {
        var peer = flashlightPeers[peerid];
        
        // Consider peer connected if it's been less than x seconds since
        // lastConnected
        var lastConnected = Date.parse(peer.lastConnected);
        var delta = new Date().getTime() - Date.parse(peer.lastConnected);
        peer.connected = delta < 30000;
        
        // Add peer to model
        model.peers.push(peer);
        
        if (peer.bpsUpDn) {
          flashlightRate += peer.bpsUpDn;
        }
      }
      
      // Total rate is lanternRate + flashlightRate
      model.instanceStats.allBytes.rate =
        model.instanceStats.allBytes.lanternRate + flashlightRate;
    }
    
    return {
      connect: connect,
      updateModel: updateModel,
    };
  });
