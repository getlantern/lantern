'use strict';

var fs = require('fs'),
    sleep = require('./node_modules/sleep'),
    faye = require('./node_modules/faye'),
    _ = require('../app/lib/lodash.js')._,
    constants = require('../app/js/constants.js'),
      MODEL_SYNC_CHANNEL = constants.MODEL_SYNC_CHANNEL,
    helpers = require('../app/js/helpers.js'),
      makeLogger = helpers.makeLogger,
        log = makeLogger('bayeux');

// XXX better name?
function BayeuxBackend() {
  this.bayeux = new faye.NodeAdapter({mount: '/cometd', timeout: 45});
  this.clients = {};
  this._bindCallbacks();
}

BayeuxBackend.VERSION = {
  major: 0,
  minor: 0,
  patch: 1
};

var RESETMODEL = JSON.parse(fs.readFileSync(__dirname+'/RESETMODEL.json'));
RESETMODEL.version.installed.bayeuxProtocol = BayeuxBackend.VERSION;

BayeuxBackend.prototype.resetModel = function() {
  this.model = _.cloneDeep(RESETMODEL);
};

BayeuxBackend.prototype.attachServer = function(http_server) {
  this.bayeux.attach(http_server);
};

BayeuxBackend.prototype.publishSync = function(patch) {
  if (_.isEmpty(this.clients)) return;
  if (!patch) patch = [{op: 'replace', path: '', value: this.model}];
  this.bayeux.getClient().publish(MODEL_SYNC_CHANNEL, patch);
};

BayeuxBackend.prototype._bindCallbacks = function() {
  var this_ = this, bayeux = this.bayeux;

  bayeux.bind('handshake', function(clientId) {
    log('[handshake]', 'client:', clientId);
    // uncomment to delay connection:
    //sleep.usleep(2000000);
  });

  bayeux.bind('subscribe', function(clientId, channel) {
    log('[subscribe]', 'client:', clientId, 'channel:', channel);
    if (channel === MODEL_SYNC_CHANNEL)
      this_.clients[clientId] = true;
    this_.publishSync();
  });

  bayeux.bind('unsubscribe', function(clientId, channel) {
    log('[unsubscribe]', 'client:', clientId, 'channel:', channel);
    if (channel === MODEL_SYNC_CHANNEL)
      delete this_.clients[clientId];
  });

  /*
  bayeux.bind('publish', function(clientId, channel, data) {
    log('[publish]', '\nclient:', clientId, '\nchannel:', channel, '\ndata:', data);
  });
  */

  bayeux.bind('disconnect', function(clientId) {
    log('[disconnect]', 'client:', clientId);
  });
};


exports.BayeuxBackend = BayeuxBackend;
