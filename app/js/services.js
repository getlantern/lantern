'use strict';

angular.module('app.services', [])
  .constant('APIVER', '0.0.1')
  // enums
  .constant('MODE', {
    give: 'give',
    get: 'get'
  })
  .constant('STATUS_GTALK', {
    notConnected: 'notConnected',
    connecting: 'connecting',
    connected: 'connected'
  })
  .constant('MODAL', {
    passwordCreate: 'passwordCreate',
    settingsUnlock: 'settingsUnlock',
    settingsLoadFailure: 'settingsLoadFailure',
    welcome: 'welcome',
    signin: 'signin',
    gtalkUnreachable: 'gtalkUnreachable',
    notInvited: 'notInvited',
    requestInvite: 'requestInvite',
    requestSent: 'requestSent',
    firstInviteReceived: 'firstInviteReceived',
    sysproxy: 'sysproxy',
    finished: 'finished',
    '': ''
  })
  .service('ENUMS', function(MODE, STATUS_GTALK, MODAL) {
    return {
      MODE: MODE,
      STATUS_GTALK: STATUS_GTALK,
      MODAL: MODAL
    };
  })
  // more flexible log service
  // https://groups.google.com/d/msg/angular/vgMF3i3Uq2Y/q1fY_iIvkhUJ
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
  .constant('COMETDURL', location.protocol+'//'+location.host+'/cometd')
  .service('cometdSrvc', function(COMETDURL, logFactory, $rootScope, $window) {
    var log = logFactory('cometdSrvc');
    // boilerplate cometd setup
    // http://cometd.org/documentation/cometd-javascript/subscription
    var cometd = $.cometd,
        connected = false,
        clientId,
        subscriptions = [];
    cometd.configure({
      url: COMETDURL,
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

    function subscribe(channel, callback) {
      var sub = null;
      if (connected) {
        sub = cometd.subscribe(channel, callback);
        log.debug('subscribed to channel', channel);
      } else {
        log.debug('queuing subscription request for channel', channel)
      }
      var key = {sub: sub, chan: channel, cb: callback};
      subscriptions.push(key);
    }

    function unsubscribe(subscription) {
      cometd.unsubscribe(subscription);
      log.debug('unsubscribed', subscription);
    }

    function refresh() {
      log.debug('refreshing subscriptions');
      angular.forEach(subscriptions, function(key) {
        if (key.sub)
          unsubscribe(key.sub);
      });
      var tmp = subscriptions;
      subscriptions = [];
      angular.forEach(tmp, function(key) {
        subscribe(key.chan, key.cb);
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
      // just for the developer panel:
      publish: function(channel, data){ cometd.publish(channel, data); }
    };
  })
  .service('modelSchema', function(ENUMS) {
    return {
      // XXX finish populating this from SPECS.md
      description: 'Lantern UI data model',
      type: 'object',
      properties: {
        settings: {
          type: 'object',
          description: 'User-specific state and configuration',
          properties: {
            mode: {
              type: 'string',
              'enum': Object.keys(ENUMS.MODE)
            }
          }
        },
        connectivity: {
          type: 'object',
          description: 'Connectivity status of various services',
          properties: {
            internet: {
              type: 'boolean',
              description: 'Whether the system has internet connectivity'
            },
            gtalk: {
              type: 'string',
              description: 'Google Talk connection status',
              'enum': Object.keys(ENUMS.STATUS_GTALK)
            },
            peers: {
              type: 'integer',
              minimum: 0,
              description: 'The number of peers online'
            }
          }
        },
        modal: {
          type: 'string',
          description: 'Instructs the UI to display the corresponding modal dialog.',
          'enum': Object.keys(ENUMS.MODAL)
        }
      }
    };
  })
  .service('modelValidatorSrvc', function(modelSchema, logFactory) {
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
  .service('modelSrvc', function($rootScope, cometdSrvc, logFactory, modelValidatorSrvc) {
    var log = logFactory('modelSrvc'),
        model = {},
        lastModel = {};
        //sanityMap = {};

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
          if (typeof obj == 'undefined') {
            lastObj[property] = obj = {};
          }
        }
      });
      lastObj[property] = angular.copy(value);
    }

    function handleSync(msg) {
      var data = msg.data,
          valid = true;
       // valid = modelValidatorSrvc.validate(data.path, data.value); // XXX
      if (valid) {
        //sanityMap[data.path] = true;
        log.debug('syncing: path:', data.path, 'value:', data.value);
        set(model, data.path, data.value);
        set(lastModel, data.path, data.value);
        $rootScope.$apply();
        log.debug('handleSync: applied sync: path:', data.path, 'value:', data.value);
      } else {
        //sanityMap[data.path] = false;
        log.debug('handleSync: rejected sync, invalid model:', data);
      }
    }

    cometdSrvc.subscribe('/sync', handleSync);

    return {
      model: model,
      get: function(path){ return get(model, path); },
      // just for the developer panel
      lastModel: lastModel
    //sane: function(){ return _.all(sanityMap); }, // XXX
    };
  })
  .service('apiSrvc', function(APIVER) {
    return {
      urlfor: function(endpoint, params) {
          var query = _.reduce(params, function(acc, val, key) {
              return acc+key+'='+encodeURIComponent(val)+'&';
            }, '?');
          return '/api/'+APIVER+'/'+endpoint+query;
        }
    };
  });
