(function() {
  'use strict';

  var noop = angular.noop;
  var objectFreeze  = (Object.freeze) ? Object.freeze : noop;
  var objectDefineProperty = Object.defineProperty;
  var isString   = angular.isString;
  var isFunction = angular.isFunction;
  var isDefined  = angular.isDefined;
  var isObject   = angular.isObject;
  var isArray    = angular.isArray;
  var arraySlice = Array.prototype.slice;
  // ie8 wat
  if (!Array.prototype.indexOf) {
    Array.prototype.indexOf = function(elt /*, from*/) {
      var len = this.length >>> 0;
      var from = Number(arguments[1]) || 0;
      from = (from < 0) ? Math.ceil(from) : Math.floor(from);
      if (from < 0) {
        from += len;
      }

      for (; from < len; from++) {
        if (from in this && this[from] === elt) { return from; }
      }
      return -1;
    };
  }
  // ie8 wat
  if (!Function.prototype.bind) {
    Function.prototype.bind = function(oThis) {
      if (typeof this !== 'function') {
        // closest thing possible to the ECMAScript 5
        // internal IsCallable function
        throw new TypeError('Function.prototype.bind - what is trying to be bound is not callable');
      }

      var aArgs   = arraySlice.call(arguments, 1),
          fToBind = this,
          FNOP    = function() {},
          fBound  = function() {
            return fToBind.apply(this instanceof FNOP && oThis ? this : oThis, aArgs.concat(arraySlice.call(arguments)));
          };

      FNOP.prototype = this.prototype;
      fBound.prototype = new FNOP();

      return fBound;
    };
  }

  // $WebSocketProvider.$inject = ['$rootScope', '$q', '$timeout', '$websocketBackend'];
  function $WebSocketProvider($rootScope, $q, $timeout, $websocketBackend) {

    function $WebSocket(url, protocols, options) {
      if (!options && isObject(protocols) && !isArray(protocols)) {
        options = protocols;
        protocols = undefined;
      }

      this.protocols = protocols;
      this.url = url || 'Missing URL';
      this.ssl = /(wss)/i.test(this.url);

      // this.binaryType = '';
      // this.extensions = '';
      // this.bufferedAmount = 0;
      // this.trasnmitting = false;
      // this.buffer = [];

      // TODO: refactor options to use isDefined
      this.scope              = options && options.scope             || $rootScope;
      this.rootScopeFailover  = options && options.rootScopeFailover && true;
      this.useApplyAsync      = options && options.useApplyAsync     || false;
      this._reconnectAttempts = options && options.reconnectAttempts || 0;
      this.initialTimeout     = options && options.initialTimeout    || 500; // 500ms
      this.maxTimeout         = options && options.maxTimeout        || 5 * 60 * 1000; // 5 minutes

      this.sendQueue          = [];
      this.onOpenCallbacks    = [];
      this.onMessageCallbacks = [];
      this.onErrorCallbacks   = [];
      this.onCloseCallbacks   = [];

      objectFreeze(this._readyStateConstants);

      if (url) {
        this._connect();
      } else {
        this._setInternalState(0);
      }

    }

    $WebSocket.prototype._readyStateConstants = {
      'CONNECTING': 0,
      'OPEN': 1,
      'CLOSING': 2,
      'CLOSED': 3,
      'RECONNECT_ABORTED': 4
    };

    $WebSocket.prototype._reconnectableStatusCodes = [
      4000
    ];

    $WebSocket.prototype.safeDigest = function safeDigest(autoApply) {
      if (autoApply && !this.scope.$$phase) {
        this.scope.$digest();
      }
    };

    $WebSocket.prototype.bindToScope = function bindToScope(scope) {
      var self = this;
      if (scope) {
        this.scope = scope;
        if (this.rootScopeFailover) {
          this.scope.$on('$destroy', function() {
            self.scope = $rootScope;
          });
        }
      }
      return self;
    };

    $WebSocket.prototype._connect = function _connect(force) {
      if (force || !this.socket || this.socket.readyState !== this._readyStateConstants.OPEN) {
        this.socket = $websocketBackend.create(this.url, this.protocols);
        this.socket.onmessage = this._onMessageHandler.bind(this);
        this.socket.onopen  = this._onOpenHandler.bind(this);
        this.socket.onerror = this._onErrorHandler.bind(this);
        this.socket.onclose = this._onCloseHandler.bind(this);
      }
    };

    $WebSocket.prototype.fireQueue = function fireQueue() {
      while (this.sendQueue.length && this.socket.readyState === this._readyStateConstants.OPEN) {
        var data = this.sendQueue.shift();

        this.socket.send(
          isString(data.message) ? data.message : JSON.stringify(data.message)
        );
        data.deferred.resolve();
      }
    };

    $WebSocket.prototype.notifyOpenCallbacks = function notifyOpenCallbacks(event) {
      for (var i = 0; i < this.onOpenCallbacks.length; i++) {
        this.onOpenCallbacks[i].call(this, event);
      }
    };

    $WebSocket.prototype.notifyCloseCallbacks = function notifyCloseCallbacks(event) {
      for (var i = 0; i < this.onCloseCallbacks.length; i++) {
        this.onCloseCallbacks[i].call(this, event);
      }
    };

    $WebSocket.prototype.notifyErrorCallbacks = function notifyErrorCallbacks(event) {
      for (var i = 0; i < this.onErrorCallbacks.length; i++) {
        this.onErrorCallbacks[i].call(this, event);
      }
    };

    $WebSocket.prototype.onOpen = function onOpen(cb) {
      this.onOpenCallbacks.push(cb);
      return this;
    };

    $WebSocket.prototype.onClose = function onClose(cb) {
      this.onCloseCallbacks.push(cb);
      return this;
    };

    $WebSocket.prototype.onError = function onError(cb) {
      this.onErrorCallbacks.push(cb);
      return this;
    };


    $WebSocket.prototype.onMessage = function onMessage(callback, options) {
      if (!isFunction(callback)) {
        throw new Error('Callback must be a function');
      }

      if (options && isDefined(options.filter) && !isString(options.filter) && !(options.filter instanceof RegExp)) {
        throw new Error('Pattern must be a string or regular expression');
      }

      this.onMessageCallbacks.push({
        fn: callback,
        pattern: options ? options.filter : undefined,
        autoApply: options ? options.autoApply : true
      });
      return this;
    };

    $WebSocket.prototype._onOpenHandler = function _onOpenHandler(event) {
      this._reconnectAttempts = 0;
      this.notifyOpenCallbacks(event);
      this.fireQueue();
    };

    $WebSocket.prototype._onCloseHandler = function _onCloseHandler(event) {
      this.notifyCloseCallbacks(event);
      if (this._reconnectableStatusCodes.indexOf(event.code) > -1) {
        this.reconnect();
      }
    };

    $WebSocket.prototype._onErrorHandler = function _onErrorHandler(event) {
      this.notifyErrorCallbacks(event);
    };

    $WebSocket.prototype._onMessageHandler = function _onMessageHandler(message) {
      var pattern;
      var self = this;
      var currentCallback;
      for (var i = 0; i < self.onMessageCallbacks.length; i++) {
        currentCallback = self.onMessageCallbacks[i];
        pattern = currentCallback.pattern;
        if (pattern) {
          if (isString(pattern) && message.data === pattern) {
            applyAsyncOrDigest(currentCallback.fn, currentCallback.autoApply, message);
          }
          else if (pattern instanceof RegExp && pattern.exec(message.data)) {
            applyAsyncOrDigest(currentCallback.fn, currentCallback.autoApply, message);
          }
        }
        else {
          applyAsyncOrDigest(currentCallback.fn, currentCallback.autoApply, message);
        }
      }

      function applyAsyncOrDigest(callback, autoApply, args) {
        args = arraySlice.call(arguments, 2);
        if (self.useApplyAsync) {
          self.scope.$applyAsync(function() {
            callback.apply(self, args);
          });
        } else {
          callback.apply(self, args);
          self.safeDigest(autoApply);
        }
      }

    };

    $WebSocket.prototype.close = function close(force) {
      if (force || !this.socket.bufferedAmount) {
        this.socket.close();
      }
      return this;
    };

    $WebSocket.prototype.send = function send(data) {
      var deferred = $q.defer();
      var self = this;
      var promise = cancelableify(deferred.promise);

      if (self.readyState === self._readyStateConstants.RECONNECT_ABORTED) {
        deferred.reject('Socket connection has been closed');
      }
      else {
        self.sendQueue.push({
          message: data,
          deferred: deferred
        });
        self.fireQueue();
      }

      // Credit goes to @btford
      function cancelableify(promise) {
        promise.cancel = cancel;
        var then = promise.then;
        promise.then = function() {
          var newPromise = then.apply(this, arguments);
          return cancelableify(newPromise);
        };
        return promise;
      }

      function cancel(reason) {
        self.sendQueue.splice(self.sendQueue.indexOf(data), 1);
        deferred.reject(reason);
        return self;
      }

      return promise;
    };

    $WebSocket.prototype.reconnect = function reconnect() {
      this.close();

      $timeout(this._connect.bind(this), this._getBackoffDelay(++this._reconnectAttempts));

      return this;
    };
    // Exponential Backoff Formula by Prof. Douglas Thain
    // http://dthain.blogspot.co.uk/2009/02/exponential-backoff-in-distributed.html
    $WebSocket.prototype._getBackoffDelay = function _getBackoffDelay(attempt) {
      var R = Math.random() + 1;
      var T = this.initialTimeout;
      var F = 2;
      var N = attempt;
      var M = this.maxTimeout;

      return Math.floor(Math.min(R * T * Math.pow(F, N), M));
    };

    $WebSocket.prototype._setInternalState = function _setInternalState(state) {
      if (Math.floor(state) !== state || state < 0 || state > 4) {
        throw new Error('state must be an integer between 0 and 4, got: ' + state);
      }

      // ie8 wat
      if (!objectDefineProperty) {
        this.readyState = state || this.socket.readyState;
      }
      this._internalConnectionState = state;


      angular.forEach(this.sendQueue, function(pending) {
        pending.deferred.reject('Message cancelled due to closed socket connection');
      });
    };

    // Read only .readyState
    if (objectDefineProperty) {
      objectDefineProperty($WebSocket.prototype, 'readyState', {
        get: function() {
          return this._internalConnectionState || this.socket.readyState;
        },
        set: function() {
          throw new Error('The readyState property is read-only');
        }
      });
    }

    return function(url, protocols) {
      return new $WebSocket(url, protocols);
    };
  }

  // $WebSocketBackendProvider.$inject = ['$window', '$log'];
  function $WebSocketBackendProvider($window, $log) {
    this.create = function create(url, protocols) {
      var match = /wss?:\/\//.exec(url);
      var Socket, ws;
      if (!match) {
        throw new Error('Invalid url provided');
      }

      // CommonJS
      if (typeof exports === 'object' && require) {
        try {
          ws = require('ws');
          Socket = (ws.Client || ws.client || ws);
        } catch(e) {}
      }

      // Browser
      Socket = Socket || $window.WebSocket || $window.MozWebSocket;

      if (protocols) {
        return new Socket(url, protocols);
      }

      return new Socket(url);
    };
    this.createWebSocketBackend = function createWebSocketBackend(url, protocols) {
      $log.warn('Deprecated: Please use .create(url, protocols)');
      return this.create(url, protocols);
    };
  }

  angular.module('ngWebSocket', [])
  .factory('$websocket', ['$rootScope', '$q', '$timeout', '$websocketBackend', $WebSocketProvider])
  .factory('WebSocket',  ['$rootScope', '$q', '$timeout', 'WebsocketBackend',  $WebSocketProvider])
  .service('$websocketBackend', ['$window', '$log', $WebSocketBackendProvider])
  .service('WebSocketBackend',  ['$window', '$log', $WebSocketBackendProvider]);


  angular.module('angular-websocket', ['ngWebSocket']);

}());
