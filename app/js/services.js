'use strict';

angular.module('app.services', [])
  // enums
  .constant('SETTINGS_STATE', {
    locked: 'locked',
    unlocked: 'unlocked',
    corrupt: 'corrupt'
  })
  .constant('SETUP_SCREENS', {
    welcome: 'welcome',
    signin: 'signin',
    sysproxy: 'sysproxy',
    finished: 'finished'
  })
  // enum service
  .factory('enums', function(SETTINGS_STATE, SETUP_SCREENS) {
    return {
      SETTINGS_STATE: SETTINGS_STATE,
      SETUP_SCREENS: SETUP_SCREENS
    };
  })
  // more flexible log service
  // @see https://groups.google.com/d/msg/angular/vgMF3i3Uq2Y/q1fY_iIvkhUJ
  .value('logWhiteList', /.*Ctrl|.*Srvc/)
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
  .factory('cometdSrvc', function(cometdUrl, logFactory, $rootScope, $window) {
    var log = logFactory('cometdSrvc');
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
      var sub = cometd.subscribe(channel, syncHandler),
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

    function publish(channel, msg) {
      log.debug('publishing on channel', channel, ':', msg);
      cometd.publish(channel, msg);
    }

    return {
      publish: publish,
      subscribe: subscribe
    };
  })
  .factory('modelSchema', function(enums) {
    return {
      // XXX finish populating this from SPECS.md
      description: 'Lantern UI data model',
      type: 'object',
      properties: {
        settings: {
          type: 'object',
          description: 'User-specific state and configuration',
          properties: {
            state: {
              type: 'string',
              'enum': Object.keys(enums.SETTINGS_STATE)
            }
          }
        },
        setupScreen: {
          type: 'string',
          description: 'If present, Lantern UI displays the corresponding setup screen.',
          'enum': Object.keys(enums.SETUP_SCREENS)
        }
      }
    };
  })
  .factory('modelValidatorSrvc', function(modelSchema, logFactory) {
    var log = logFactory('modelValidatorSrvc');

    function getSchema(path) {
      var schema = modelSchema;
      angular.forEach(path.split('.'), function(name) {
        if (name && typeof schema != 'undefined')
          schema = schema.properties[name];
      });
      return schema;
    }

    // XXX use real json schema validator
    function validate(path, value) {
      var schema = getSchema(path);
      if (!schema) return true;
      if (typeof value != schema.type) return false;
      var enum_ = schema['enum'];
      if (enum_) {
        var pat = new RegExp('^('+enum_.join('|')+')$');
        if (!pat.test(value)) return false;
      }
      return true;
    }

    return {
      validate: validate
    };
  })
  .factory('modelSrvc', function($rootScope, cometdSrvc, logFactory, modelValidatorSrvc) {
    var log = logFactory('modelSrvc'),
        model = {},
        connected = false,
        sanityMap = {};

    function get(obj, path) {
      var val = obj;
      angular.forEach(path.split('.'), function(name) {
        if (name && typeof val != 'undefined')
          val = val[name];
      });
      return val;
    }

    function set(obj, path, value) {
      if (!path) return angular.copy(value, obj);
      var lastObj = obj, property;
      angular.forEach(path.split('.'), function(name) {
        if (name) {
          lastObj = obj;
          obj = obj[property=name];
          if (!obj) {
            lastObj[property] = obj = {};
          }
        }
      });
      lastObj[property] = angular.copy(value);
    }

    function handleSync(msg) {
      var data = msg.data;
      if (modelValidatorSrvc.validate(data.path, data.value)) {
        set(model, data.path, data.value);
        sanityMap[data.path] = true;
      } else {
        log.debug('handleSync rejecting invalid value:', data.value);
        sanityMap[data.path] = false;
      }
      $rootScope.$apply();
    }

    $rootScope.$on('cometdConnEstablished', function() {
      cometdSrvc.subscribe('/sync', handleSync);
      connected = true;
    });

    $rootScope.$on('cometdConnBroken', function() {
      connected = false;
      $rootScope.$apply();
    });

    return {
      model: model,
      get: function(path) { return get(model, path); },
      sane: function(){ return _.all(sanityMap); },
      connected: function(){ return connected; }
    };
  });
