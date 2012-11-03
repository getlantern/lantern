var fs = require('fs')
  , util = require('util')
  , faye = require('./node_modules/faye')
  ;


var RESETMODEL = JSON.parse(fs.readFileSync(__dirname+'/RESETMODEL.json'));


function BayeuxBackend() {
  this._bayeux = new faye.NodeAdapter({mount: '/cometd', timeout: 45});
  this.resetModel();
  this._bindCallbacks();
}

BayeuxBackend.prototype.attachServer = function(http_server) {
  this._bayeux.attach(http_server);
}

BayeuxBackend.prototype.resetModel = function() {
  this.model = JSON.parse(JSON.stringify(RESETMODEL)); // quick and dirty clone
};

BayeuxBackend.prototype._getModelValue = function(path) {
  var val = this.model;
  path.split('.').forEach(function(name) {
    if (name && typeof val != 'undefined')
      val = val[name];
  });
  return val;
};

BayeuxBackend.prototype.publishSync = function(path) {
  path = path || '';
  var value = this._getModelValue(path);
  // this._bayeux.getClient().publish({ // XXX why doesn't this work?
  this._bayeux._server._engine.publish({
    channel: '/sync',
    data: {path: path, value: value}
  });
};

BayeuxBackend.prototype._bindCallbacks = function() {
  var self = this
    , bayeux = this._bayeux
    ;

  bayeux.bind('handshake', function(clientId) {
    util.puts('[bayeux] handshake: client: '+clientId);
  });

  bayeux.bind('subscribe', function(clientId, channel) {
    util.puts('[bayeux] subscribe: client: '+clientId+', channel: '+channel);
    util.puts('[bayeux]            publishing entire state to /sync channel');
    self.publishSync();
    //util.puts(util.inspect(self.model));
  });

  bayeux.bind('unsubscribe', function(clientId, channel) {
    util.puts('[bayeux] unsubscribe: client ' + clientId + ', channel ' + channel);
  });

  bayeux.bind('publish', function(clientId, channel, data) {
    //util.puts('[bayeux] got publish: '+clientId+' '+channel+' '+util.inspect(data, false, 4, true));
    if (channel == '/sync' && typeof clientId != 'undefined') {
      util.puts('[bayeux] syncing client publication: client:'+clientId+
        ', data:\n'+util.inspect(data, false, 4, true));
      _sync(self.model, data.path, data.value);
    }
  });

  bayeux.bind('disconnect', function(clientId) {
    util.puts('[bayeux] disconnect: client ' + clientId);
  });
};


function _sync(obj, path, value) {
  var lastObj = obj;
  var property;
  path.split('.').forEach(function(name) {
    if (name) {
      lastObj = obj;
      obj = obj[property=name];
      if (!obj) {
        lastObj[property] = obj = {};
      }
    }
  });
  if (typeof property != 'undefined') {
    lastObj[property] = value;
  } else {
    lastObj = value;
  }
}

exports.BayeuxBackend = BayeuxBackend;
