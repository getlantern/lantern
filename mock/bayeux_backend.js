'use strict';

var fs = require('fs'),
    sleep = require('./node_modules/sleep'),
    faye = require('./node_modules/faye'),
    _ = require('../app/lib/lodash.js')._,
    constants = require('../app/js/constants.js'),
      MODEL_SYNC_CHANNEL = constants.MODEL_SYNC_CHANNEL,
    helpers = require('../app/js/helpers.js'),
      getByPath = helpers.getByPath,
      merge = helpers.merge;

var log = helpers.makeLogger('bayeux');

var RESETMODEL = JSON.parse(fs.readFileSync(__dirname+'/RESETMODEL.json'));


function BayeuxBackend() {
  this._bayeux = new faye.NodeAdapter({mount: '/cometd', timeout: 45});
  this._clients = {};
  this._bindCallbacks();
}

BayeuxBackend.VERSION = {
  major: 0,
  minor: 0,
  patch: 1
};

BayeuxBackend.prototype.attachServer = function(http_server) {
  this._bayeux.attach(http_server);
};

BayeuxBackend.prototype.resetModel = function() {
  this.model = _.cloneDeep(RESETMODEL);
  merge(this.model, {bayeuxProtocol: BayeuxBackend.VERSION}, 'version.installed');
};

BayeuxBackend.prototype.publishSync = function(path) {
  if (_.isEmpty(this._clients)) {
    log('[publishSync]', 'no clients to publish to');
    return;
  }
  path = path || '';
  var value = getByPath(this.model, path);
  //log('[publishSync]', '\npath:', path, '\nvalue:', value);
  // this._bayeux.getClient().publish({ // XXX why doesn't this work?
  this._bayeux._server._engine.publish({
    channel: MODEL_SYNC_CHANNEL,
    data: {path: path, value: value}
  });
};

BayeuxBackend.prototype._bindCallbacks = function() {
  var self = this, bayeux = this._bayeux;

  bayeux.bind('handshake', function(clientId) {
    log('[handshake]', 'client:', clientId);
    // uncomment to delay connection:
    //sleep.usleep(2000000);
  });

  bayeux.bind('subscribe', function(clientId, channel) {
    log('[subscribe]', 'client:', clientId, 'channel:', channel);
    if (channel == MODEL_SYNC_CHANNEL)
      self._clients[clientId] = true;
    self.publishSync(); // XXX publish only to this client
  });

  bayeux.bind('unsubscribe', function(clientId, channel) {
    log('[unsubscribe]', 'client:', clientId, 'channel:', channel);
    if (channel == MODEL_SYNC_CHANNEL)
      delete self._clients[clientId];
  });

  /*
  bayeux.bind('publish', function(clientId, channel, data) {
    log('[publish]', 'client:', clientId, 'channel:', channel, 'data:', data);
  });
  */

  bayeux.bind('disconnect', function(clientId) {
    log('[disconnect]', 'client:', clientId);
  });
};


exports.BayeuxBackend = BayeuxBackend;
