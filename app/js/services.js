angular.module('app.services', [])
  // more flexible log service
  // @see https://groups.google.com/d/msg/angular/vgMF3i3Uq2Y/q1fY_iIvkhUJ
  .value('logWhiteList', /.*Ctrl|cometd/)
  .factory('logFactory', function($log, debug, logWhiteList) {
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
      return {
        log:   extracted('log'),
        warn:  extracted('warn'),
        error: extracted('error'),
        debug: debug ? extracted('log') : angular.noop
      };
    }
  })
  .factory('cometdUrl', function($location) {
    return $location.protocol()+'://'+$location.host()+':'+$location.port()+
      '/cometd';
  })
  .factory('cometd', function(cometdUrl, logFactory, $rootScope, $q, $window) {
    var log = logFactory('cometd');
    // boilerplate cometd setup
    // @see http://cometd.org/documentation/cometd-javascript/subscription
    var cometd = $.cometd,
        connected = false,
        subscriptions = {};
    cometd.configure({url: cometdUrl/*, logLevel: 'debug'*/});
    //cometd.websocketEnabled = true; // XXX re-enable in Lantern

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
        $rootScope.$broadcast('cometdConnEstablished');
      } else if (wasConnected && !connected) {
        log.warn('connection broken');
        $rootScope.$broadcast('cometdConnBroken');
      }
    });

    // XXX backend should never send a disconnect message
    cometd.addListener('/meta/disconnect', function(msg) {
      log.debug('got disconnect');
      if (msg.successful) {
        connected = false;
        log.debug('connection closed');
        // XXX broadcast event, handle where necessary
      }
    });

    function subscribe(channel, syncHandler) {
      log.debug('subscribing to channel', channel);
      sub = cometd.subscribe(channel, syncHandler);
      key = {sub: sub, chan: channel, cb: syncHandler};
      subscriptions[key] = true;
      return key;
    }

    function unsubscribe(key) {
      if (subscriptions[key]) {
        log.debug('unsubscribing', key);
        cometd.unsubscribe(key.sub);
        delete subscriptions[key];
      } else {
        log.error('no such subscription', key);
      }
    }

    function refresh() {
      angular.forEach(angular.copy(subscriptions), function(_, key) {
        unsubscribe(key);
        subscribe(key.chan, key.cb);
      });
    }

    cometd.addListener('/meta/handshake', function(handshake) {
      if (handshake.successful) {
        log.debug('successful handshake');
        cometd.batch(function() {
          refresh();
        });
      }
      else {
        log.warn('unsuccessful handshake');
      }
    });

    $($window).unload(function() {
      cometd.disconnect(true);
    });

    cometd.handshake();

    return {
      subscribe: subscribe
      };
  })
  .factory('syncedModel', function($rootScope, logFactory, cometd) {
    //var log = logFactory(...);

    var model = {};
    var connected = false;

    function set(obj, path, value) {
      if (!path) return angular.copy(value, obj);
      var lastObj = obj;
      var property;
      angular.forEach(path.split('.'), function(name) {
        if (name) {
          lastObj = obj;
          obj = obj[property=name];
          obj || lastObj[property] = obj = {};
        }
      });
      lastObj[property] = angular.copy(value);
    }

    function handleSync(msg) {
      var data = msg.data;
      set(model, data.path, data.value);
      $rootScope.$apply();
    }

    $rootScope.$on('cometdConnEstablished', function() {
      cometd.subscribe('/sync', handleSync);
      connected = true;
    });

    $rootScope.$on('cometdConnBroken', function() {
      connected = false;
      $rootScope.$apply();
    });

    return {
      model: model,
      connected: function(){ return connected; }
    };
  });
