'use strict';

var url = require('url'),
    sleep = require('./node_modules/sleep'),
    _ = require('../app/lib/lodash.js')._,
    helpers = require('../app/js/helpers.js'),
      makeLogger = helpers.makeLogger,
        log = makeLogger('api'),
      getByPath = helpers.getByPath,
      deleteByPath = helpers.deleteByPath,
      merge = helpers.merge,
    scenarios = require('./scenarios'),
      SCENARIOS = scenarios.SCENARIOS,
    constants = require('../app/js/constants.js'),
      EMAIL = constants.INPUT_PAT.EMAIL,
      LANG = constants.LANG,
      ENUMS = constants.ENUMS,
        CONNECTIVITY = ENUMS.CONNECTIVITY,
        INTERACTION = ENUMS.INTERACTION,
        MODAL = ENUMS.MODAL,
        MODE = ENUMS.MODE,
        OS = ENUMS.OS,
        SETTING = ENUMS.SETTING;

function ApiServlet(bayeuxBackend) {
  this._bayeuxBackend = bayeuxBackend;
  this.publishSync = bayeuxBackend.publishSync.bind(bayeuxBackend);
  this.resetModel = bayeuxBackend.resetModel.bind(bayeuxBackend);
  this.reset();
  this._DEFAULT_PROXIED_SITES = bayeuxBackend.model.settings.proxiedSites.slice(0);
  this.MODALSEQ_GIVE = [MODAL.welcome, MODAL.authorize, MODAL.lanternFriends, MODAL.finished, MODAL.none];
  this.MODALSEQ_GET = [MODAL.welcome, MODAL.authorize, MODAL.lanternFriends, MODAL.proxiedSites, MODAL.systemProxy, MODAL.finished, MODAL.none];
}

ApiServlet.VERSION = {
  major: 0,
  minor: 0,
  patch: 1
  };
ApiServlet.MOUNT_POINT = 'api';

ApiServlet.RESET_INTERNAL_STATE = {
  lastModal: MODAL.none,
  modalsCompleted: {
    welcome: false,
    authorize: false,
    proxiedSites: false,
    systemProxy: false,
    lanternFriends: false,
    finished: false
  },
  appliedScenarios: {
    os: 'osx',
    location: 'beijing',
    internet: 'true',
    gtalkAuthorized: 'true',
    invited: 'true',
    ninvites: '10',
    gtalkReachable: 'true',
    roster: 'roster1',
    friends: 'friends1',
    peers: 'peers1'
  }
};

ApiServlet.prototype.reset = function() {
  this._internalState = _.cloneDeep(ApiServlet.RESET_INTERNAL_STATE);
  this.resetModel();
  this.model = this._bayeuxBackend.model;
  merge(this.model, {
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
  this.publishSync();
};

// XXX better name for this
ApiServlet.prototype.flattened = function(data) {
  var update = {};
  update[data.path] = data.value;
  return update;
};

ApiServlet.prototype.updateModel = function(state, publish) {
  for (var path in state) {
    merge(this.model, state[path], path);
    if (publish)
      this.publishSync(path);
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

ApiServlet._handlerForInteraction = {};
ApiServlet._handlerForInteraction[INTERACTION.developer] = function(res, data) {
  if (!_.isArray(data)) throw Error('Expected array');
  // XXX validate requested updates
  for (var i=0, update=data[i]; update; update=data[++i]) {
    if (update.delete) {
      deleteByPath(this.model, update.path);
    } else {
      deleteByPath(this.model, update.path);
      merge(this.model, update.value, update.path);
    }
    this.publishSync(update.path);
  }
};

ApiServlet._handlerForInteraction[INTERACTION.contact] = function(res, data) {
  if (this.model.modal == MODAL.contact) return;
  this._internalState.lastModal = this.model.modal;
  this.updateModel({modal: MODAL.contact}, true);
};

ApiServlet._handlerForInteraction[INTERACTION.scenarios] = function(res, data) {
  if (this.model.modal == MODAL.scenarios) return;
  this._internalState.lastModal = this.model.modal;
  this.updateModel({modal: MODAL.scenarios}, true);
};

ApiServlet._handlerForModal = {};
ApiServlet._handlerForModal[MODAL.contact] = function(interaction, res, data) {
  if (interaction != INTERACTION.continue && interaction != INTERACTION.cancel) {
    res.writeHead(400);
    return;
  }
  if (interaction == INTERACTION.continue) {
    log('received message:', data.message);
    // XXX notify user message was sent in an alert
  }
  this.updateModel({modal: this._internalState.lastModal}, true);
  this._internalState.lastModal = MODAL.none;
};

ApiServlet._handlerForModal[MODAL.scenarios] = function(interaction, res, data) {
  if (interaction != INTERACTION.continue ||
     (data.path && data.path != 'mock.scenarios.applied')) {
    res.writeHead(400);
    return;
  }
  var appliedScenarios = data.value;
  for (var groupKey in appliedScenarios) {
    var scenKey = appliedScenarios[groupKey];
    if (!getByPath(SCENARIOS, groupKey+'.'+scenKey)) {
      log('No such scenario', groupKey+'.'+scenKey);
      res.writeHead(400);
      return;
    }
    if (getByPath(this.model, 'mock.scenarios.applied.'+groupKey) != scenKey) {
      var scen = getByPath(SCENARIOS, groupKey+'.'+scenKey);
      log('applying scenario:', scen.desc);
      scen.func.call(this);
    }
  }
  this.updateModel({'mock.scenarios.applied': appliedScenarios,
    'mock.scenarios.prompt': '', 'modal': this._internalState.lastModal}, true);
  this._internalState.lastModal = MODAL.none;
};


ApiServlet._handlerForModal[MODAL.welcome] = function(interaction, res, data) {
  // user can set language from welcome screen
  if (interaction == INTERACTION.set && data &&
      data.path == 'settings.lang' && data.value in LANG) {
    this.updateModel(this.flattened(data), true);
    return;
  }
  if (!(interaction in MODE)) return res.writeHead(400);
  if (interaction == MODE.give && this.inCensoringCountry()) {
    this.updateModel({modal: MODAL.giveModeForbidden}, true);
    return;
  }
  this.updateModel({'settings.mode': interaction}, true);
  this._internalState.modalsCompleted[MODAL.welcome] = true;
  this._advanceModal();
};

ApiServlet._handlerForModal[MODAL.giveModeForbidden] = function(interaction, res) {
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

ApiServlet._handlerForModal[MODAL.authorize] = function(interaction, res) {
  if (interaction != INTERACTION.continue) return res.writeHead(400);

  // check for gtalk authorization
  var scen = getByPath(this.model, 'mock.scenarios.applied.gtalkAuthorized');
  scen = getByPath(SCENARIOS, 'gtalkAuthorized.'+scen);
  if (!scen) {
    this._internalState.lastModal = MODAL.authorize;
    this.updateModel({modal: MODAL.scenarios,
      'mock.scenarios.prompt': 'No oauth scenario applied.'}, true);
    return;
  }
  log('applying gtalkAuthorized scenario', scen.desc);
  scen.func.call(this);
  if (!getByPath(this.model, 'connectivity.gtalkAuthorized')) {
    log('Google Talk access not granted, user must authorize');
    return;
  }

  // check for lantern access
  // XXX show this in UI?
  scen = getByPath(this.model, 'mock.scenarios.applied.invited');
  scen = getByPath(SCENARIOS, 'invited.'+scen);
  if (!scen) {
    this._internalState.lastModal = MODAL.authorize;
    this.updateModel({modal: MODAL.scenarios,
      'mock.scenarios.prompt': 'No Lantern access scenario applied.'}, true);
    return;
  }
  log('applying Lantern access scenario', scen.desc);
  scen.func.call(this);
  if (!getByPath(this.model, 'connectivity.invited')) {
    this.updateModel({modal: MODAL.notInvited}, true);
    return;
  }

  // try connecting to google talk
  scen = getByPath(this.model, 'mock.scenarios.applied.gtalkReachable');
  scen = getByPath(SCENARIOS, 'gtalkReachable.'+scen);
  if (!scen) {
    this._internalState.lastModal = MODAL.authorize;
    this.updateModel({modal: MODAL.scenarios,
      'mock.scenarios.prompt': 'No gtalkReachable scenario applied.'}, true);
    return;
  }
  log('applying gtalkReachable scenario', scen.desc);
  scen.func.call(this);
  if (getByPath(this.model, 'connectivity.gtalk') != CONNECTIVITY.connected) {
    this.updateModel({modal: MODAL.gtalkUnreachable}, true);
    return;
  }

  // fetch number of invites
  scen = getByPath(this.model, 'mock.scenarios.applied.ninvites');
  scen = getByPath(SCENARIOS, 'ninvites.'+scen);
  if (!scen) {
    this._internalState.lastModal = MODAL.authorize;
    this.updateModel({modal: MODAL.scenarios,
      'mock.scenarios.prompt': 'No ninvites scenario applied.'}, true);
    return;
  }
  log('applying ninvites scenario', scen.desc);
  scen.func.call(this);

  // fetch roster
  // XXX show this in UI?
  scen = getByPath(this.model, 'mock.scenarios.applied.roster');
  scen = getByPath(SCENARIOS, 'roster.'+scen);
  if (!scen) {
    this._internalState.lastModal = MODAL.authorize;
    this.updateModel({modal: MODAL.scenarios,
      'mock.scenarios.prompt': 'No roster scenario applied.'}, true);
    return;
  }
  log('applying roster scenario', scen.desc);
  scen.func.call(this);

  // fetch lantern friends
  scen = getByPath(this.model, 'mock.scenarios.applied.friends');
  scen = getByPath(SCENARIOS, 'friends.'+scen);
  if (!scen) {
    this._internalState.lastModal = MODAL.authorize;
    this.updateModel({modal: MODAL.scenarios,
      'mock.scenarios.prompt': 'No friends scenario applied.'}, true);
    return;
  }
  log('applying friends scenario', scen.desc);
  scen.func.call(this);

  // peer discovery and connection
  // XXX show this in UI?
  scen = getByPath(this.model, 'mock.scenarios.applied.peers');
  scen = getByPath(SCENARIOS, 'peers.'+scen);
  if (!scen) {
    this._internalState.lastModal = MODAL.authorize;
    this.updateModel({modal: MODAL.scenarios,
      'mock.scenarios.prompt': 'No peers scenario applied.'}, true);
    return;
  }
  log('applying peers scenario', scen.desc);
  scen.func.call(this);
  this._internalState.modalsCompleted[MODAL.authorize] = true;
  this._advanceModal();
};

ApiServlet._handlerForModal[MODAL.proxiedSites] = function(interaction, res, data) {
  if (interaction == INTERACTION.continue) {
    this._internalState.modalsCompleted[MODAL.proxiedSites] = true;
    this._advanceModal(MODAL.settings);
  } else if (interaction == INTERACTION.set) {
    this.updateModel({'settings.proxiedSites': data.value}, true);
  } else if (interaction == INTERACTION.reset) {
    this.updateModel({'settings.proxiedSites': this._DEFAULT_PROXIED_SITES}, true);
  } else {
    res.writeHead(400);
  }
};

ApiServlet._handlerForModal[MODAL.systemProxy] = function(interaction, res, data) {
  if (interaction != INTERACTION.continue ||
      data.path != 'settings.systemProxy') {
    res.writeHead(400);
    return;
  }
  this.updateModel({'settings.systemProxy': data.value}, true);
  if (data.value) sleep.usleep(750000);
  this._internalState.modalsCompleted[MODAL.systemProxy] = true;
  this._advanceModal(MODAL.settings);
};

function _matchIndex(collection, item, field) {
  for (var i=0, ii=collection[i]; ii; ii = collection[++i]) {
    if (item[field] == ii[field])
      return i;
  }
  return -1;
}
ApiServlet._handlerForModal[MODAL.lanternFriends] = function(interaction, res, data) {
  if (interaction == INTERACTION.continue) {
    if (data && data.invite) {
      if (data.invite.length > this.model.ninvites) {
        log('more invitees than invites', data);
        return res.writeHead(400);
      }
      for (var i=0, ii=data.invite[i]; ii; ii=data.invite[++i]) {
        if (!EMAIL.test(ii)) {
          log('not a valid email:', ii);
          return res.writeHead(400);
        }
      }
      this.updateModel({'ninvites': this.model.ninvites - data.invite.length}, true);
      log('invitations will be sent to', data.invite);
    }
    this._internalState.modalsCompleted[MODAL.lanternFriends] = true;
    this._advanceModal();
  } else if (interaction == INTERACTION.accept ||
             interaction == INTERACTION.decline) {
    var pending = getByPath(this.model, 'friends.pending', []),
        i = _matchIndex(pending, data, 'email');
    if (i == -1) return res.writeHead(400);
    pending.splice(i, 1);
    this.publishSync('friends.pending');
    if (interaction == INTERACTION.accept) {
      this.model.friends.current.push(data);
      this.publishSync('friends.current.'+(this.model.friends.current.length-1));
      this.model.roster.push(data);
      this.publishSync('roster.'+(this.model.roster.length-1));
    }
  } else {
    res.writeHead(400);
  }
};

ApiServlet._handlerForModal[MODAL.gtalkUnreachable] = function(interaction, res) {
  if (interaction == INTERACTION.retry) {
    this.updateModel({modal: MODAL.authorize}, true);
  } else if (interaction == INTERACTION.retryLater) {
    this.updateModel({modal: MODAL.authorizeLater}, true);
  } else {
    res.writeHead(400);
  }
};

ApiServlet._handlerForModal[MODAL.authorizeLater] = function(interaction, res) {
  if (interaction != INTERACTION.continue) {
    res.writeHead(400);
    return;
  }
  this.updateModel({modal: MODAL.none, showVis: true}, true);
};

ApiServlet._handlerForModal[MODAL.notInvited] = function(interaction, res) {
  if (interaction == INTERACTION.retry) {
    this.updateModel({modal: MODAL.authorize}, true);
  } else if (interaction == INTERACTION.requestInvite) {
    this.updateModel({modal: MODAL.requestInvite}, true);
  } else {
    res.writeHead(400);
  }
};

ApiServlet._handlerForModal[MODAL.requestSent] = function(interaction, res) {
  if (interaction != INTERACTION.continue) return res.writeHead(400);
  this.updateModel({modal: MODAL.none, showVis: true}, true);
};

ApiServlet._handlerForModal[MODAL.firstInviteReceived] = function(interaction, res) {
  if (interaction != INTERACTION.continue) return res.writeHead(400);
  this._advanceModal();
};

ApiServlet._handlerForModal[MODAL.finished] = function(interaction, res, data) {
  if (interaction == INTERACTION.set && data &&
      data.path == ('settings.'+SETTING.autoReport) && _.isBoolean(data.value)) {
    this.updateModel(this.flattened(data), true);
    return;
  }
  if (interaction != INTERACTION.continue) return res.writeHead(400);
  this._internalState.modalsCompleted[MODAL.finished] = true;
  this._advanceModal();
  this.updateModel({setupComplete: true, showVis: true}, true);
};

ApiServlet._handlerForModal[MODAL.settings] = function(interaction, res, data) {
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
  } else if (interaction == INTERACTION.set) {
    var path = (data.path || '').split('.'),
        settings = path[0], setting = path[1];
    if (settings != 'settings' || !(setting in SETTING)) return res.writeHead(400);
    this.updateModel(this.flattened(data), true);
  } else {
    res.writeHead(400);
  }
};

ApiServlet._handlerForModal[MODAL.about] = 
ApiServlet._handlerForModal[MODAL.updateAvailable] = function(interaction, res) {
  if (interaction != INTERACTION.close) return res.writeHead(400);
  this.updateModel({modal: MODAL.none}, true);
};

ApiServlet._handlerForModal[MODAL.confirmReset] = function(interaction, res) {
  if (interaction == INTERACTION.cancel) {
    this.updateModel({modal: MODAL.settings}, true);
  } else if (interaction == INTERACTION.reset) {
    this.reset();
  } else {
    res.writeHead(400);
  }
};
    
ApiServlet._handlerForModal[MODAL.none] = function(interaction, res) {
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
  var self = this, handled = false;
  log(req.url.href);
  // POST /api/<x.y.z>/interaction/<interactionid>
  if (req.method != 'POST') {
    res.writeHead(405);
  } else {
    var path = url.parse(req.url).pathname,
        parts = path.split('/'),
        mnt = parts[1],
        verstr = parts[2],
        ver = (verstr || '').split('.'),
        interaction = parts[3],
        interactionid = parts[4];
    if (mnt != ApiServlet.MOUNT_POINT ||
        ver[0] != ApiServlet.VERSION.major ||
        ver[1] != ApiServlet.VERSION.minor ||
        interaction != 'interaction' ||
        !(interactionid in INTERACTION)) {
      res.writeHead(404);
    } else {
      var data = '', error = false;
      req.addListener('data', function(chunk) { data += chunk; });
      req.addListener('end', function() {
        if (data) {
          try {
            data = JSON.parse(data);
            log('got data:', data);
          } catch (e) {
            log('Error parsing JSON:', e)
            res.writeHead(400);
            error = true;
          }
        }
        if (!error) {
          if (interactionid in ApiServlet._handlerForInteraction) {
            var handler = ApiServlet._handlerForInteraction[interactionid];
            if (handler)
              handler.call(self, res, data);
            else
              res.writeHead(404);
          } else {
            var handler = ApiServlet._handlerForModal[self.model.modal];
            if (handler)
              handler.call(self, interactionid, res, data);
            else
              res.writeHead(404);
          }
        }
        res.end();
        log(res.statusCode);
      });
      handled = true;
    }
  }
  if (!handled) {
    res.end();
    log(res.statusCode);
  }
};


exports.ApiServlet = ApiServlet;
