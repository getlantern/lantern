'use strict';

var fs = require('fs'),
    faye = require('./node_modules/faye'),
    _ = require('../app/lib/lodash.js')._,
    helpers = require('../app/js/helpers.js'),
      getByPath = helpers.getByPath,
      deleteByPath = helpers.deleteByPath,
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
  this.model = _.clone(RESETMODEL, true);
  merge(this.model, {bayeuxProtocol: BayeuxBackend.VERSION}, 'version.installed');
};

BayeuxBackend.prototype.publishSync = function(path) {
  if (_.isEmpty(this._clients)) {
    log('[publishSync]', 'no clients to publish to');
    return;
  }
  path = path || '';
  var value = getByPath(this.model, path);
  log('[publishSync]', '\npath:', path, '\nvalue:', value);
  // this._bayeux.getClient().publish({ // XXX why doesn't this work?
  this._bayeux._server._engine.publish({
    channel: '/sync',
    data: {path: path, value: value}
  });
};

BayeuxBackend.prototype._bindCallbacks = function() {
  var self = this, bayeux = this._bayeux;

  bayeux.bind('handshake', function(clientId) {
    log('[handshake]', 'client:', clientId);
    self._clients[clientId] = true;
  });

  bayeux.bind('subscribe', function(clientId, channel) {
    log('[subscribe]', 'client:', clientId, 'channel:', channel);
    self.publishSync();
  });

  bayeux.bind('unsubscribe', function(clientId, channel) {
    log('[unsubscribe]', 'client:', clientId, 'channel:', channel);
  });

  bayeux.bind('publish', function(clientId, channel, data) {
    if (channel == '/sync' && !_.isUndefined(clientId)) {
      log('[syncing client publication]', 'client:', clientId, 'data:\n', data);
      if (data.delete) {
        deleteByPath(self.model, data.path);
      } else {
        deleteByPath(self.model, data.path);
        merge(self.model, data.value, data.path);
      }
    }
  });

  bayeux.bind('disconnect', function(clientId) {
    log('[disconnect]', 'client:', clientId);
    delete self._clients[clientId];
  });
};


exports.BayeuxBackend = BayeuxBackend;
