'use strict';

var url = require('url'),
    util = require('util'),
    sleep = require('./node_modules/sleep'),
    helpers = require('./helpers'),
    getByPath = helpers.getByPath,
    merge = helpers.merge,
    validatePasswords = helpers.validatePasswords,
    scenarios = require('./scenarios'),
    SCENARIOS = scenarios.SCENARIOS,
    enums = require('./enums'),
    CONNECTIVITY = enums.CONNECTIVITY,
    INTERACTION = enums.INTERACTION,
    MODAL = enums.MODAL,
    MODE = enums.MODE,
    OS = enums.OS;

function ApiServlet(bayeuxBackend) {
  this._bayeuxBackend = bayeuxBackend;
  this.publishSync = bayeuxBackend.publishSync.bind(bayeuxBackend);
  this.resetModel = bayeuxBackend.resetModel.bind(bayeuxBackend);
  this.reset();
  this._DEFAULT_PROXIED_SITES = bayeuxBackend.model.settings.proxiedSites.slice(0);
  this.MODALSEQ_GIVE = [MODAL.welcome, MODAL.passwordCreate, MODAL.authorize, MODAL.lanternFriends, MODAL.finished, MODAL.none];
  this.MODALSEQ_GET = [MODAL.welcome, MODAL.passwordCreate, MODAL.authorize, MODAL.proxiedSites, MODAL.systemProxy, MODAL.lanternFriends, MODAL.finished, MODAL.none];
}

ApiServlet.VERSION = {
  major: 0,
  minor: 0,
  patch: 1
  };
ApiServlet.VERSION_STR = ApiServlet.VERSION.major+'.'+ApiServlet.VERSION.minor;
ApiServlet.MOUNT_POINT = '/api/';
ApiServlet.API_PREFIX = ApiServlet.MOUNT_POINT + ApiServlet.VERSION_STR + '/';

ApiServlet.RESET_INTERNAL_STATE = {
  lastModal: MODAL.none,
  modalsCompleted: {
    welcome: false,
    passwordCreate: false,
    authorize: false,
    proxiedSites: false,
    systemProxy: false,
    lanternFriends: false,
    finished: false
  },
  appliedScenarios: {
    os: 'osx',
    location: 'beijing',
    internet: 'connection',
    oauth: 'authorized',
    lanternAccess: 'access',
    gtalkConnect: 'reachable',
    roster: 'contactsOnline',
    peers: 'peersOnline'
  }
};

ApiServlet.prototype.reset = function() {
  this._internalState = JSON.parse(JSON.stringify(ApiServlet.RESET_INTERNAL_STATE)); // quick and dirty clone
  this.resetModel();
  this.model = this._bayeuxBackend.model;
  helpers.merge(this.model, '', {
    version: {installed: {httpApi: ApiServlet.VERSION}},
    mock: {scenarios: {applied: {}, all: SCENARIOS}}
  });
  var applied = this._internalState.appliedScenarios;
  for (var groupKey in applied) {
    var groupObj = getByPath(SCENARIOS, groupKey),
        scenKey = applied[groupKey],
        scenObj = groupObj[scenKey];
    if (groupObj._applyImmediately || scenObj._applyImmediately)
      scenObj.func.call(this);
    this.model.mock.scenarios.applied[groupKey] = scenKey;
  }
  if (!this.passwordCreateRequired()) {
    this._internalState.modalsCompleted.passwordCreate = true;
  }
  this.publishSync();
};

ApiServlet.prototype.updateModel = function(updates, publish) {
  for (var path in updates) {
    merge(this.model, path, updates[path]);
    publish && this.publishSync(path);
  }
};

/*
 * Show next modal that should be shown, including possibly MODAL.none.
 * Needed because some modals can be skipped if the user is
 * unable to complete them, but should be returned to later.
 * */
ApiServlet.prototype._advanceModal = function(backToIfNone) {
  var modalSeq = this.inGiveMode() ? this.MODALSEQ_GIVE : this.MODALSEQ_GET,
      next;
  for (var i=0; this._internalState.modalsCompleted[next=modalSeq[i++]];);
  if (backToIfNone && next == MODAL.none)
    next = backToIfNone;
  log('next modal:', next);
  this.updateModel({modal: next}, true);
};


ApiServlet.prototype.inCensoringCountry = function() {
  return this.model.countries[this.model.location.country].censors;
};

ApiServlet.prototype.inGiveMode = function() {
  return this.model.settings.mode == MODE.give;
};

ApiServlet.prototype.inGetMode = function() {
  return this.model.settings.mode == MODE.get;
};

ApiServlet.prototype.passwordCreateRequired = function() {
  return this.model.system.os == OS.ubuntu && !this._internalState.password;
};

ApiServlet._handlers = {};
ApiServlet._handlers.passwordCreate = function(res, qs) {
  if (!validatePasswords(qs.password1, qs.password2)) {
    res.writeHead(400);
    return;
  }
  this._internalState.password = qs.password1;
  this._internalState.modalsCompleted[MODAL.passwordCreate] = true;
  this.updateModel({modal: MODAL.authorize}, true);
};

ApiServlet._handlers.state = function(res, qs) {
  // XXX validate requested changes via model schema before applying them
  var updates = JSON.parse(qs.updates);
  this.updateModel(updates, true);
  log('applied state updates', updates);
};

ApiServlet._handlers['settings/unlock'] = function(res, qs) {
  if (qs.password != this._internalState.password) {
    res.writeHead(403);
    return;
  }
  this._advanceModal();
};

ApiServlet._handlers.requestInvite = function(res, qs) {
  sleep.usleep(750000);
  this.updateModel({modal: MODAL.requestSent}, true);
};

ApiServlet._handlers.interaction = function(res, qs) {
  var interaction = qs.interaction;
  if (interaction == INTERACTION.scenarios) {
    this._internalState.lastModal = this.model.modal;
    this.updateModel({modal: MODAL.scenarios}, true);
    return;
  }
  var handler = ApiServlet._intHandlerForModal[this.model.modal];
  if (!handler) return res.writeHead(400);
  return handler.call(this, interaction, res, qs);
};

ApiServlet._intHandlerForModal = {};
ApiServlet._intHandlerForModal[MODAL.scenarios] = function(interaction, res, qs) {
  if (interaction != INTERACTION.continue) return res.writeHead(400);
  var appliedScenarios = JSON.parse(qs.appliedScenarios);
  log("appliedScenarios:", appliedScenarios);
  // XXX validate
  this.updateModel({'mock.scenarios.applied': appliedScenarios,
    'mock.scenarios.prompt': '', 'modal': this._internalState.lastModal}, true);
  this._internalState.lastModal = MODAL.none;
};


ApiServlet._intHandlerForModal[MODAL.welcome] = function(interaction, res) {
  if (!(interaction in MODE)) return res.writeHead(400);
  if (interaction == MODE.give && this.inCensoringCountry()) {
    this.updateModel({modal: MODAL.giveModeForbidden}, true);
    return;
  }
  this.updateModel({'settings.mode': interaction}, true);
  this._internalState.modalsCompleted[MODAL.welcome] = true;
  this._advanceModal();
};

ApiServlet._intHandlerForModal[MODAL.giveModeForbidden] = function(interaction, res) {
  if (interaction == INTERACTION.continue) {
    this.updateModel({mode: MODE.get}, true);
    this._internalState.modalsCompleted[MODAL.welcome] = true;
    this._advanceModal(MODAL.settings);
  } else if (interaction == INTERACTION.cancel && !this._internalState.modalsCompleted[MODAL.welcome]) {
    this.updateModel({modal: MODAL.welcome}, true);
  } else {
    res.writeHead(400);
  }
};

ApiServlet._intHandlerForModal[MODAL.authorize] = function(interaction, res) {
  if (interaction != INTERACTION.continue) return res.writeHead(400);

  // check for gtalk authorization
  var scen = getByPath(this.model, 'mock.scenarios.applied.oauth');
  scen = getByPath(this.model, 'mock.scenarios.all.oauth.'+scen);
  if (!scen) {
    this._internalState.lastModal = MODAL.authorize;
    this.updateModel({modal: MODAL.scenarios,
      'mock.scenarios.prompt': 'No oauth scenario applied.'}, true);
    return;
  }
  log('applying oauth scenario', scen.desc);
  // XXX what if can't reach google here?
  scen.func.call(this);
  if (!getByPath(this.model, 'connectivity.gtalkAuthorized')) {
    log('Google Talk access not granted, user must authorize');
    return;
  }

  // check for lantern access
  // XXX show this in UI?
  scen = getByPath(this.model, 'mock.scenarios.applied.lanternAccess');
  scen = getByPath(this.model, 'mock.scenarios.all.lanternAccess.'+scen);
  if (!scen) {
    this._internalState.lastModal = MODAL.authorize;
    this.updateModel({modal: MODAL.scenarios,
      'mock.scenarios.prompt': 'No Lantern access scenario applied.'}, true);
    return;
  }
  log('applying Lantern access scenario', scen.desc);
  // XXX what if can't reach google here?
  scen.func.call(this);
  if (!getByPath(this.model, 'connectivity.lanternAccess')) {
    this.updateModel({modal: MODAL.notInvited}, true);
    return;
  }

  // connect to google talk
  scen = getByPath(this.model, 'mock.scenarios.applied.gtalkConnect');
  scen = getByPath(this.model, 'mock.scenarios.all.gtalkConnect.'+scen);
  if (!scen) {
    this._internalState.lastModal = MODAL.authorize;
    this.updateModel({modal: MODAL.scenarios,
      'mock.scenarios.prompt': 'No gtalkConnect scenario applied.'}, true);
    return;
  }
  log('applying gtalkConnect scenario', scen.desc);
  scen.func.call(this);
  if (getByPath(this.model, 'connectivity.gtalk') != CONNECTIVITY.connected) {
    this.updateModel({modal: MODAL.gtalkUnreachable}, true);
    return;
  }

  // fetch roster
  // XXX show this in UI?
  scen = getByPath(this.model, 'mock.scenarios.applied.roster');
  scen = getByPath(this.model, 'mock.scenarios.all.roster.'+scen);
  if (!scen) {
    this._internalState.lastModal = MODAL.authorize;
    this.updateModel({modal: MODAL.scenarios,
      'mock.scenarios.prompt': 'No roster scenario applied.'}, true);
    return;
  }
  log('applying roster scenario', scen.desc);
  scen.func.call(this);
  if (getByPath(this.model, 'connectivity.gtalk') != CONNECTIVITY.connected) {
    this.updateModel({modal: MODAL.gtalkUnreachable}, true);
    return;
  }

  // peer discovery and connection
  // XXX show this in UI?
  scen = getByPath(this.model, 'mock.scenarios.applied.peers');
  scen = getByPath(this.model, 'mock.scenarios.all.peers.'+scen);
  if (!scen) {
    this._internalState.lastModal = MODAL.authorize;
    this.updateModel({modal: MODAL.scenarios,
      'mock.scenarios.prompt': 'No peers scenario applied.'}, true);
    return;
  }
  log('applying peers scenario', scen.desc);
  scen.func.call(this);
  if (getByPath(this.model, 'connectivity.gtalk') != CONNECTIVITY.connected) {
    this.updateModel({modal: MODAL.gtalkUnreachable}, true);
    return;
  }
  this._internalState.modalsCompleted[MODAL.authorize] = true;
  this._advanceModal();
};

ApiServlet._intHandlerForModal[MODAL.proxiedSites] = function(interaction, res) {
  if (interaction == INTERACTION.continue) {
    this._internalState.modalsCompleted[MODAL.proxiedSites] = true;
    this._advanceModal(MODAL.settings);
  } else if (interaction == INTERACTION.reset) {
    this.updateModel({'settings.proxiedSites': this._DEFAULT_PROXIED_SITES}, true);
  } else {
    res.writeHead(400);
  }
};

ApiServlet._intHandlerForModal[MODAL.systemProxy] = function(interaction, res, qs) {
  var systemProxy = qs.systemProxy;
  if (interaction != INTERACTION.continue ||
     (systemProxy != 'true' && systemProxy != 'false')) {
    res.writeHead(400);
    return;
  }
  systemProxy = systemProxy == 'true';
  this.updateModel({'settings.systemProxy': systemProxy}, true);
  if (systemProxy) sleep.usleep(750000);
  this._internalState.modalsCompleted[MODAL.systemProxy] = true;
  this._advanceModal(MODAL.settings);
};

ApiServlet._intHandlerForModal[MODAL.lanternFriends] = function(interaction, res) {
  if (interaction != INTERACTION.continue) return res.writeHead(400);
  this._internalState.modalsCompleted[MODAL.lanternFriends] = true;
  this._advanceModal();
};

ApiServlet._intHandlerForModal[MODAL.gtalkUnreachable] = function(interaction, res) {
  if (interaction == INTERACTION.retryNow) {
    this._tryConnect(); // XXX handle via scenario
  } else if (interaction == INTERACTION.retryLater) {
    this.updateModel({modal: MODAL.authorizeLater}, true);
  } else {
    res.writeHead(400);
  }
};

ApiServlet._intHandlerForModal[MODAL.authorizeLater] = function(interaction, res) {
  if (interaction != INTERACTION.continue) {
    res.writeHead(400);
    return;
  }
  this.updateModel({modal: MODAL.none, showVis: true}, true);
};

ApiServlet._intHandlerForModal[MODAL.notInvited] = function(interaction, res) {
  if (interaction != INTERACTION.requestInvite) return res.writeHead(400);
  this.updateModel({modal: MODAL.requestInvite}, true);
};

ApiServlet._intHandlerForModal[MODAL.requestSent] = function(interaction, res) {
  if (interaction != INTERACTION.continue) return res.writeHead(400);
  this.updateModel({modal: MODAL.none, showVis: true}, true);
};

ApiServlet._intHandlerForModal[MODAL.firstInviteReceived] = function(interaction, res) {
  if (interaction != INTERACTION.continue) return res.writeHead(400);
  this._advanceModal();
};

ApiServlet._intHandlerForModal[MODAL.finished] = function(interaction, res) {
  if (interaction != INTERACTION.continue) return res.writeHead(400);
  this._internalState.modalsCompleted[MODAL.finished] = true;
  this._advanceModal();
  this.updateModel({setupComplete: true, showVis: true}, true);
};

ApiServlet._intHandlerForModal[MODAL.settings] = function(interaction, res) {
  if (interaction in MODE) {
    if (interaction == MODE.give && this.inCensoringCountry()) {
      this.updateModel({modal: MODAL.giveModeForbidden}, true);
      res.writeHead(400);
      return;
    }
    var wasInGiveMode = this.inGiveMode();
    if (wasInGiveMode && this.model.settings.systemProxy)
      sleep.usleep(750000);
    this.updateModel({'settings.mode': interaction}, true);
    this._advanceModal(MODAL.settings);
  } else if (interaction == INTERACTION.proxiedSites) {
    this.updateModel({modal: MODAL.proxiedSites}, true);
  } else if (interaction == INTERACTION.close) {
    this.updateModel({modal: MODAL.none}, true);
  } else if (interaction == INTERACTION.reset) {
    this.updateModel({modal: MODAL.confirmReset}, true);
  } else {
    res.writeHead(400);
  }
};

ApiServlet._intHandlerForModal[MODAL.about] = 
ApiServlet._intHandlerForModal[MODAL.updateAvailable] = function(interaction, res) {
  if (interaction != INTERACTION.close) return res.writeHead(400);
  this.updateModel({modal: MODAL.none}, true);
};

ApiServlet._intHandlerForModal[MODAL.confirmReset] = function(interaction, res) {
  if (interaction == INTERACTION.cancel) {
    this.updateModel({modal: MODAL.settings}, true);
  } else if (interaction == INTERACTION.reset) {
    this.reset();
  } else {
    res.writeHead(400);
  }
};
    
ApiServlet._intHandlerForModal[MODAL.none] = function(interaction, res) {
  switch (interaction) {
    case INTERACTION.lanternFriends:
      if (this.model.connectivity.gtalk != CONNECTIVITY.connected) {
        // sign-in required XXX explain this to user
        this.updateModel({modal: MODAL.authorize}, true);
        return;
      }
      // otherwise fall through to no-sign-in-required cases:
    case INTERACTION.about:
    case INTERACTION.updateAvailable:
    case INTERACTION.settings: // XXX check if signed in on clientside and only allow configuring settings accordingly
      this.updateModel({modal: interaction}, true);
      return;
    default:
      res.writeHead(400);
  }
};

ApiServlet.prototype.handleRequest = function(req, res) {
  var parsed = url.parse(req.url, true),
      qs = parsed.query,
      prefix = parsed.pathname.substring(0, ApiServlet.API_PREFIX.length),
      endpoint = parsed.pathname.substring(ApiServlet.API_PREFIX.length),
      handler = ApiServlet._handlers[endpoint];
  log(req.url.href);
  if (prefix == ApiServlet.API_PREFIX && handler) {
    handler.call(this, res, qs);
  } else {
    res.writeHead(404);
  }
  res.end();
  log(res.statusCode);
};

function log() {
  var s = '[api] ';
  for (var i=0, l=arguments.length, ii=arguments[i]; i<l; ii=arguments[++i])
    s += (typeof ii == 'object' ? util.inspect(ii, false, null, true) : ii)+' ';
  util.puts(s);
}

exports.ApiServlet = ApiServlet;
