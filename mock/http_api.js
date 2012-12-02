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
  this.MODALSEQ_GIVE = [MODAL.welcome, MODAL.authorize, MODAL.inviteFriends, MODAL.finished, MODAL.none];
  this.MODALSEQ_GET = [MODAL.welcome, MODAL.authorize, MODAL.proxiedSites, MODAL.systemProxy, MODAL.inviteFriends, MODAL.finished, MODAL.none];
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
    inviteFriends: false,
    finished: false
  },
  appliedScenarios: [
    'os.osx',
    'location.beijing',
    'internet.connection',
    'gtalkConnectivity.notConnected',
    'gtalkAuthorization.notAuthorized'
  ]
};

ApiServlet.prototype.reset = function() {
  this._internalState = JSON.parse(JSON.stringify(ApiServlet.RESET_INTERNAL_STATE)); // quick and dirty clone
  this.resetModel();
  this.model = this._bayeuxBackend.model;
  helpers.merge(this.model, '', {
    version: {installed: {httpApi: ApiServlet.VERSION}},
    mock: {scenarios: {applied: [], all: SCENARIOS}}
  });
  var self = this;
  this._internalState.appliedScenarios.forEach(
    function(path) {
      var scenario = getByPath(SCENARIOS, path);
      scenario.func.call(self);
      self.model.mock.scenarios.applied.push(path);
    }
  );
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
  log('next', next);
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

ApiServlet._handlers['settings/'] = function(res, qs) {
  // XXX validate requested changes via model schema before applying them
  this.updateModel(qs.updates, true);
};

ApiServlet._handlers['settings/unlock'] = function(res, qs) {
  if (qs.password != this._internalState.password) {
    res.writeHead(403);
    return;
  }
  this._advanceModal();
};

ApiServlet._handlers.oauthAuthorized = function(res, qs) {
  // XXX handle via scenario
  this.updateModel({'settings.userid': qs.userid,
    'connectivity.gtalkAuthorized': true
  }, true);
  this._internalState.modalsCompleted[MODAL.authorize] = true;
  this._tryConnect();
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
  var appliedScenarios = qs.appliedScenarios;
  log("appliedScenarios:", util.inspect(appliedScenarios));
  // XXX parse and validate
  this.updateModel({'mock.scenarios.applied': appliedScenarios,
    'modal': this._internalState.lastModal
  }, true);
  this._internalState.lastModal = MODAL.none;
};


ApiServlet._intHandlerForModal[MODAL.welcome] = function(interaction, res) {
  if (!(interaction in MODE)) return res.writeHead(400);
  if (interaction == MODE.give && this.inCensoringCountry()) {
    this.updateModel({modal: MODAL.giveModeForbidden}, true);
    return;
  }
  this.updateModel({'settings.mode': interaction,
    'modal': this.passwordCreateRequired() ? MODAL.passwordCreate : MODAL.authorize
  }, true);
  this._internalState.modalsCompleted[MODAL.welcome] = true;
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

    /*
    var scenario = getByPath(this.model, 'mock.scenarios.all.'+ii);
    if (scenario) {
      scenario()
    */

ApiServlet._intHandlerForModal[MODAL.authorize] = function(interaction, res) {
  if (interaction != INTERACTION.continue) return res.writeHead(400);
  var gtalkAuthScenarioPath;
  for (var i=0, applied=getByPath(this.model, 'mock.scenarios.applied.length', []),
       ii=applied[i]; ii && !gtalkAuthScenarioPath; ii=applied[++i]) {
    if (/gtalkAuthorization/.test(ii)) gtalkAuthScenarioPath = ii;
  }
  if (!gtalkAuthScenarioPath) {
    this.updateModel({modal: MODAL.scenarios,
      'mock.scenarios.prompt': 'No gtalkAuthorization scenario applied.'}, true);
    return;
  }
  var gtalkAuthScenario = getByPath(this.model, 'mock.scenarios.all.'+gtalkAuthScenarioPath);
  if (!gtalkAuthScenario) {
    this.updateModel({modal: MODAL.scenarios,
      'mock.scenarios.prompt': 'No matching gtalkAuthorization scenario for '+gtalkAuthScenarioPath}, true);
    return;
  }
  log('applying gtalkAuthScenario', gtalkAuthScenarioPath);
  gtalkAuthScenario.func.call(this);
  //XXX this would go inside the scenario:
  //this._internalState.modalsCompleted[MODAL.authorize] = true;
  //this._advanceModal(MODAL.settings);
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

ApiServlet._intHandlerForModal[MODAL.inviteFriends] = function(interaction, res) {
  if (interaction != INTERACTION.continue) return res.writeHead(400);
  this._internalState.modalsCompleted[MODAL.inviteFriends] = true;
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
    case INTERACTION.inviteFriends:
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
  util.puts('[api] ' + [].slice.call(arguments).join(' '));
}

exports.ApiServlet = ApiServlet;
