'use strict';

var url = require('url')
  , util = require('util')
  , sleep = require('./node_modules/sleep')
  ;


function ApiServlet(bayeuxBackend) {
  this._bayeuxBackend = bayeuxBackend;
  ApiServlet._resetInternalState.call(this);
  this._DEFAULT_PROXIED_SITES = bayeuxBackend.model.settings.proxiedSites.slice(0);
}

ApiServlet.VERSION = [0, 0, 1];
var VERSION_STR = ApiServlet.VERSION.join('.')
  , MOUNT_POINT = '/api/'
  , API_PREFIX = MOUNT_POINT + VERSION_STR + '/'
  ;

function inCensoringCountry(model) {
  return model.countries[model.location.country].censors;
}

var peer1 = {
    "peerid": "peerid1",
    "userid": "lantern_friend1@example.com",
    "mode":"give",
    "ip":"74.120.12.135",
    "lat":51,
    "lon":9,
    "country":"de",
    "type":"desktop"
    }
, peer2 = {
    "peerid": "peerid2",
    "userid": "lantern_power_user@example.com",
    "mode":"give",
    "ip":"93.182.129.82",
    "lat":55.7,
    "lon":13.1833,
    "country":"se",
    "type":"lec2proxy"
  }
, peer3 = {
    "peerid": "peerid3",
    "userid": "lantern_power_user@example.com",
    "mode":"give",
    "ip":"173.194.66.141",
    "lat":37.4192,
    "lon":-122.0574,
    "country":"us",
    "type":"laeproxy"
  }
, peer4 = {
    "peerid": "peerid4",
    "userid": "lantern_power_user@example.com",
    "mode":"give",
    "ip":"...",
    "lat":54,
    "lon":-2,
    "country":"gb",
    "type":"lec2proxy"
  }
, peer5 = {
    "peerid": "peerid5",
    "userid": "lantern_power_user@example.com",
    "mode":"get",
    "ip":"...",
    "lat":31.230381,
    "lon":121.473684,
    "country":"cn",
    "type":"desktop"
  }
;

var roster = [{
  "userid":"lantern_friend1@example.com",
  "name":"Lantern Friend1",
  "avatarUrl":"",
  "status":"available",
  "statusMessage":"",
  "peers":["peerid1"]
  }
  /* say lantern_power_user not on roster, discovered via advertisement instead
 ,{
  "userid":"lantern_power_user@example.com",
  "name":"Lantern Poweruser",
  "avatarUrl":"",
  "status":"available",
  "statusMessage":"Shanghai!",
  "peers":["peerid2", "peerid3", "peerid4", "peerid5"]
  }
  */
];

/*
model.version.updated = {
"label":"0.0.2",
"url":"https://lantern.s3.amazonaws.com/lantern-0.0.2.dmg",
"released":"2012-11-11T00:00:00Z"
}
*/


// enums
var MODE = {give: 'give', get: 'get'};
var MODAL = {
  settingsUnlock: 'settingsUnlock',
  settingsLoadFailure: 'settingsLoadFailure',
  welcome: 'welcome',
  authorize: 'authorize',
  gtalkConnecting: 'gtalkConnecting',
  gtalkUnreachable: 'gtalkUnreachable',
  authorizeLater: 'authorizeLater',
  notInvited: 'notInvited',
  requestInvite: 'requestInvite',
  requestSent: 'requestSent',
  firstInviteReceived: 'firstInviteReceived',
  proxiedSites: 'proxiedSites',
  systemProxy: 'systemProxy',
  passwordCreate: 'passwordCreate',
  inviteFriends: 'inviteFriends',
  finished: 'finished',
  contactDevs: 'contactDevs',
  settings: 'settings',
  confirmReset: 'confirmReset',
  giveModeForbidden: 'giveModeForbidden',
  about: 'about',
  updateAvailable: 'updateAvailable',
  none: ''
};
var INTERACTION = {
  inviteFriends: 'inviteFriends',
  contactDevs: 'contactDevs',
  settings: 'settings',
  proxiedSites: 'proxiedSites',
  reset: 'reset',
  about: 'about',
  updateAvailable: 'updateAvailable',
  requestInvite: 'requestInvite',
  retryNow: 'retryNow',
  retryLater: 'retryLater',
  cancel: 'cancel',
  continue: 'continue',
  close: 'close'
};
var CONNECTIVITY = {
  connected: 'connected',
  connecting: 'connecting',
  notConnected: 'notConnected'
};
var OS = {
  windows: 'windows',
  ubuntu: 'ubuntu',
  osx: 'osx'
};


// XXX in demo mode interaction(something requiring sign in) should bring up sign in

function inGiveMode(model) {
  return model.settings.mode == MODE.give;
}

function inGetMode(model) {
  return model.settings.mode == MODE.get;
}

function passwordCreateRequired(model) {
  return model.system.os == OS.ubuntu;
}

function validatePasswords(pw1, pw2) {
  return pw1 && pw2 && pw1 == pw2;
}

var RESET_INTERNAL_STATE = {
  modalsCompleted: {
    welcome: false,
    passwordCreate: false,
    authorize: false,
    proxiedSites: false,
    systemProxy: false,
    inviteFriends: false,
    finished: false
  }
};

ApiServlet._resetInternalState = function() {
  // quick and dirty clone
  this._internalState = JSON.parse(JSON.stringify(RESET_INTERNAL_STATE));
};

var MODALSEQ_GIVE = [MODAL.welcome, MODAL.authorize, MODAL.inviteFriends, MODAL.finished, MODAL.none],
     MODALSEQ_GET = [MODAL.welcome, MODAL.authorize, MODAL.proxiedSites, MODAL.systemProxy, MODAL.inviteFriends, MODAL.finished, MODAL.none];
/*
 * Show next modal that should be shown, including possibly MODAL.none.
 * Useful because some modals can be skipped if the user is
 * unable to complete them, but should be returned to later.
 * */
ApiServlet._advanceModal = function(backToIfNone) {
  var model = this._bayeuxBackend.model
    , modalSeq = inGiveMode(model) ? MODALSEQ_GIVE : MODALSEQ_GET
    , next;
  for (var i=0; this._internalState.modalsCompleted[next=modalSeq[i++]];);
  if (backToIfNone && next == MODAL.none)
    next = backToIfNone;
  model.modal = next;
  util.puts('modalsCompleted: ' + util.inspect(this._internalState.modalsCompleted));
  util.puts('next modal: ' + next);
  this._bayeuxBackend.publishSync('modal');
};

ApiServlet._tryConnect = function(model) {
  var userid = model.settings.userid;

  // connect to google talk
  model.connectivity.gtalk = CONNECTIVITY.connecting;
  this._bayeuxBackend.publishSync('connectivity.gtalk');
  model.modal = MODAL.gtalkConnecting;
  this._bayeuxBackend.publishSync('modal');
  sleep.usleep(3000000);
  if (userid ==  'user_cant_reach_gtalk@example.com') {
    model.connectivity.gtalk = CONNECTIVITY.notConnected;
    this._bayeuxBackend.publishSync('connectivity.gtalk');
    model.modal = MODAL.gtalkUnreachable;
    this._bayeuxBackend.publishSync('modal');
    util.puts("user can't reach google talk, set modal to "+MODAL.gtalkUnreachable);
    return;
  }
  model.connectivity.gtalk = CONNECTIVITY.connected;
  this._bayeuxBackend.publishSync('connectivity.gtalk');

  // refresh roster
  model.roster = roster;
  this._bayeuxBackend.publishSync('roster');
  sleep.usleep(250000);

  // check for lantern access
  if (userid != 'user_invited@example.com') {
    model.modal = MODAL.notInvited;
    this._bayeuxBackend.publishSync('modal');
    util.puts("user does not have Lantern access, set modal to "+MODAL.notInvited);
    return;
  }

  // try connecting to known peers
  // (advertised by online Lantern friends or remembered from previous connection)
  model.connectivity.peers.current = [peer1.peerid, peer2.peerid, peer3.peerid, peer4.peerid, peer5.peerid];
  model.connectivity.peers.lifetime = [peer1, peer2, peer3, peer4, peer5];
  this._bayeuxBackend.publishSync('connectivity.peers');
  util.puts("user has access; connected to google talk, fetched roster:\n"+util.inspect(roster)+"\ndiscovered and connected to peers:\n"+util.inspect(model.connectivity.peers.current));
  ApiServlet._advanceModal.call(this);
};

ApiServlet.HandlerMap = {
  passwordCreate: function(req, res) {
      var model = this._bayeuxBackend.model
        , qs = url.parse(req.url, true).query;
      if (!validatePasswords(qs.password1, qs.password2)) {
        res.writeHead(400);
      } else {
        model.modal = MODAL.authorize;
        this._internalState.modalsCompleted[MODAL.passwordCreate] = true;
        this._bayeuxBackend.publishSync('modal');
      }
    },
  'settings/unlock': function(req, res) {
      var qs = url.parse(req.url, true).query 
        , model = this._bayeuxBackend.model
        , password = qs.password
        ;
      if (!qs.password) {
        res.writeHead(400);
      } else if (qs.password == 'password') {
        model.modal = model.setupComplete ? MODAL.none : MODAL.welcome;
        this._bayeuxBackend.publishSync('modal');
      } else {
        res.writeHead(403);
      }
    },
  interaction: function(req, res) {
      var qs = url.parse(req.url, true).query 
        , model = this._bayeuxBackend.model
        , interaction = qs.interaction
        ;
      switch (model.modal) {
        case MODAL.welcome:
          if (interaction != MODE.give && interaction != MODE.get) {
            res.writeHead(400);
            return;
          }
          if (interaction == MODE.give && inCensoringCountry(model)) {
            model.modal = MODAL.giveModeForbidden;
            this._bayeuxBackend.publishSync('modal');
            res.writeHead(400);
            return;
          }
          model.settings.mode = interaction;
          model.modal = passwordCreateRequired(model) ?
                          MODAL.passwordCreate : MODAL.authorize;
          this._bayeuxBackend.publishSync('settings.mode');
          this._bayeuxBackend.publishSync('modal');
          this._internalState.modalsCompleted[MODAL.welcome] = true;
          return;

        case MODAL.giveModeForbidden:
          if (interaction == INTERACTION.continue) {
            model.settings.mode = MODE.get;
            this._bayeuxBackend.publishSync('settings.mode');
            this._internalState.modalsCompleted[MODAL.welcome] = true;
            ApiServlet._advanceModal.call(this, MODAL.settings);
            return;
          }
          if (interaction == INTERACTION.cancel && !this._internalState.modalsCompleted[MODAL.welcome]) {
            model.modal = MODAL.welcome;
            this._bayeuxBackend.publishSync('modal');
            return;
          }
          res.writeHead(400);
          return;

        case MODAL.proxiedSites:
          if (interaction == INTERACTION.continue) {
            this._internalState.modalsCompleted[MODAL.proxiedSites] = true;
            ApiServlet._advanceModal.call(this, MODAL.settings);
            return;
          }
          if (interaction == INTERACTION.reset) {
            model.proxiedSites = this._DEFAULT_PROXIED_SITES;
            this._bayeuxBackend.publishSync('proxiedSites');
            return;
          }
          res.writeHead(400);
          return;

        case MODAL.systemProxy:
          var systemProxy = qs.systemProxy;
          if (interaction != INTERACTION.continue ||
             (systemProxy != 'true' && systemProxy != 'false')) {
            res.writeHead(400);
            return;
          }
          systemProxy = systemProxy == 'true';
          model.settings.systemProxy = systemProxy;
          if (systemProxy) sleep.usleep(750000);
          this._internalState.modalsCompleted[MODAL.systemProxy] = true;
          ApiServlet._advanceModal.call(this, MODAL.settings);
          return;

        case MODAL.inviteFriends:
          if (interaction != INTERACTION.continue) {
            res.writeHead(400);
            return;
          }
          this._internalState.modalsCompleted[MODAL.inviteFriends] = true;
          ApiServlet._advanceModal.call(this);
          return;

        case MODAL.gtalkUnreachable:
          if (interaction == INTERACTION.retryNow) {
            ApiServlet._tryConnect.call(this, model);
          } else if (interaction == INTERACTION.retryLater) {
            model.modal = MODAL.authorizeLater;
            this._bayeuxBackend.publishSync('modal');
          } else {
            res.writeHead(400);
            return;
          }
          return;

        case MODAL.authorizeLater:
          if (interaction != INTERACTION.continue) {
            res.writeHead(400);
            return;
          }
          model.modal = MODAL.none;
          this._bayeuxBackend.publishSync('modal');
          model.showVis = true;
          this._bayeuxBackend.publishSync('showVis');
          return;

        case MODAL.notInvited:
          if (interaction != INTERACTION.requestInvite) {
            res.writeHead(400);
            return;
          }
          model.modal = MODAL.requestInvite;
          this._bayeuxBackend.publishSync('modal');
          return;

        case MODAL.requestSent:
          if (interaction != INTERACTION.continue) {
            res.writeHead(400);
            return;
          }
          model.modal = MODAL.none;
          this._bayeuxBackend.publishSync('modal');
          model.showVis = true;
          this._bayeuxBackend.publishSync('showVis');
          return;

        case MODAL.firstInviteReceived:
          if (interaction != INTERACTION.continue) {
            res.writeHead(400);
            return;
          }
          ApiServlet._advanceModal.call(this);
          break;

        case MODAL.finished:
          if (interaction != INTERACTION.continue) {
            res.writeHead(400);
            return;
          }
          this._internalState.modalsCompleted[MODAL.finished] = true;
          ApiServlet._advanceModal.call(this);
          model.setupComplete = true;
          this._bayeuxBackend.publishSync('setupComplete');
          model.showVis = true;
          this._bayeuxBackend.publishSync('showVis');
          return;

        case MODAL.none:
          switch (interaction) {
            case INTERACTION.inviteFriends:
            case INTERACTION.contactDevs:
              // sign-in required
              if (model.connectivity.gtalk != CONNECTIVITY.connected) {
                model.modal = MODAL.authorize;
                this._bayeuxBackend.publishSync('modal');
                return;
              }
              // otherwise fall through to no-sign-in-required cases:

            case INTERACTION.about:
            case INTERACTION.updateAvailable:
            case INTERACTION.settings: // XXX check if signed in on clientside and only allow configuring settings accordingly
              model.modal = interaction;
              this._bayeuxBackend.publishSync('modal');
              return;

            default:
              res.writeHead(400);
              return;
          }

        case MODAL.contactDevs:
          if (interaction != INTERACTION.continue) {
            res.writeHead(400);
            return;
          }
          model.modal = MODAL.none;
          this._bayeuxBackend.publishSync('modal');
          return;

        case MODAL.settings:
          if (interaction == MODE.give || interaction == MODE.get) {
            if (interaction == MODE.give && inCensoringCountry(model)) {
              model.modal = MODAL.giveModeForbidden;
              this._bayeuxBackend.publishSync('modal');
              res.writeHead(400);
              return;
            }
            var wasInGiveMode = inGiveMode(model);
            if (wasInGiveMode && model.settings.systemProxy)
              sleep.usleep(750000);
            model.settings.mode = interaction;
            this._bayeuxBackend.publishSync('settings.mode');
            ApiServlet._advanceModal.call(this, MODAL.settings);
          } else if (interaction == INTERACTION.proxiedSites) {
            model.modal = MODAL.proxiedSites;
            this._bayeuxBackend.publishSync('modal');
          } else if (interaction == INTERACTION.close) {
            model.modal = MODAL.none;
            this._bayeuxBackend.publishSync('modal');
          } else if (interaction == INTERACTION.reset) {
            model.modal = MODAL.confirmReset;
            this._bayeuxBackend.publishSync('modal');
          } else {
            res.writeHead(400);
            return;
          }
          return;

        case MODAL.about:
        case MODAL.updateAvailable:
        case MODAL.confirmReset:
          if (interaction == INTERACTION.close) {
            model.modal = MODAL.none;
            this._bayeuxBackend.publishSync('modal');
            return;
          } else if (interaction == INTERACTION.reset) {
            ApiServlet._resetInternalState.call(this);
            this._bayeuxBackend.resetModel();
            this._bayeuxBackend.publishSync();
            return;
          }
          res.writeHead(400);
          return;
        
        default:
          res.writeHead(400);
          return;
      }
    },
  'settings/': function(req, res) {
      var model = this._bayeuxBackend.model
        , qs = url.parse(req.url, true).query
        , badRequest = false
        , mode = qs.mode
        , systemProxy = qs.systemProxy
        , lang = qs.lang
        , autoReport = qs.autoReport
        , autoStart = qs.autoStart
        , proxyAllSites = qs.proxyAllSites
        , proxiedSites = qs.proxiedSites
        ;
      // XXX write this better
      if ('undefined' == typeof mode
       && 'undefined' == typeof systemProxy
       && 'undefined' == typeof lang
       && 'undefined' == typeof autoReport
       && 'undefined' == typeof autoStart
       && 'undefined' == typeof proxyAllSites
       && 'undefined' == typeof proxiedSites
          ) {
        badRequest = true;
      } else {
        if (mode) {
          if (mode != MODE.give && mode != MODE.get) {
            badRequest = true;
            util.puts('invalid value of mode: ' + mode);
          } else {
            if (inGiveMode(model) && mode == MODE.get && model.settings.systemProxy)
              sleep.usleep(750000);
            model.settings.mode = mode;
            this._bayeuxBackend.publishSync('settings.mode');
          }
        }
        if (systemProxy) {
          if (systemProxy != 'true' && systemProxy != 'false') {
            badRequest = true;
            util.puts('invalid value of systemProxy: ' + systemProxy);
          } else {
            systemProxy = systemProxy == 'true';
            if (systemProxy) sleep.usleep(750000);
            model.settings.systemProxy = systemProxy;
            this._bayeuxBackend.publishSync('settings.systemProxy');
          }
        }
        if (lang) {
          // XXX use LANG enum
          if (lang != 'en' && lang != 'zh' && lang != 'fa' && lang != 'ar') {
            badRequest = true;
            util.puts('invalid value of lang: ' + lang);
          } else {
            model.settings.lang = lang;
            this._bayeuxBackend.publishSync('settings.lang');
          }
        }
        if (autoStart) {
          if (autoStart != 'true' && autoStart != 'false') {
            badRequest = true;
            util.puts('invalid value of autoStart: ' + autoStart);
          } else {
            autoStart = autoStart == 'true';
            model.settings.autoStart = autoStart;
            this._bayeuxBackend.publishSync('settings.autoStart');
          }
        }
        if (autoReport) {
          if (autoReport != 'true' && autoReport != 'false') {
            badRequest = true;
            util.puts('invalid value of autoReport: ' + autoReport);
          } else {
            autoReport = autoReport == 'true';
            model.settings.autoReport = autoReport;
            this._bayeuxBackend.publishSync('settings.autoReport');
          }
        }
        if (proxyAllSites) {
          if (proxyAllSites != 'true' && proxyAllSites != 'false') {
            badRequest = true;
            util.puts('invalid value of proxyAllSites: ' + proxyAllSites);
          } else {
            proxyAllSites = proxyAllSites == 'true';
            model.settings.proxyAllSites = proxyAllSites;
            this._bayeuxBackend.publishSync('settings.proxyAllSites');
          }
        }
        if (proxiedSites) {
          proxiedSites = proxiedSites.split(',');
          // XXX validate
          if (false) {
            badRequest = true;
            util.puts('invalid value of proxiedSites: ' + proxiedSites);
          } else {
            model.settings.proxiedSites = proxiedSites;
            this._bayeuxBackend.publishSync('settings.proxiedSites');
          }
        }
      }
      if (badRequest) {
        res.writeHead(400);
      }
    },
  oauthAuthorized: function(req, res) {
      var model = this._bayeuxBackend.model
        , qs = url.parse(req.url, true).query 
        , userid = qs.userid
        ;
      model.settings.userid = userid;
      this._bayeuxBackend.publishSync('settings.userid');
      model.connectivity.gtalkAuthorized = true;
      this._bayeuxBackend.publishSync('connectivity.gtalkAuthorized');
      this._internalState.modalsCompleted[MODAL.authorize] = true;
      ApiServlet._tryConnect.call(this, model);
  },
  requestInvite: function(req, res) {
      var model = this._bayeuxBackend.model
        , qs = url.parse(req.url, true).query
        , lanternDevs = qs.lanternDevs
      ;
      if (typeof lanternDevs != 'undefined'
          && lanternDevs != 'true'
          && lanternDevs != 'false') {
        res.writeHead(400);
      }
      sleep.usleep(750000);
      model.modal = 'requestSent';
      this._bayeuxBackend.publishSync('modal');
    }
};

ApiServlet.prototype.handleRequest = function(req, res) {
  var parsed = url.parse(req.url)
    , prefix = parsed.pathname.substring(0, API_PREFIX.length)
    , endpoint = parsed.pathname.substring(API_PREFIX.length)
    , handler = ApiServlet.HandlerMap[endpoint]
    ;
  util.puts('[api] ' + req.url.href);
  if (prefix == API_PREFIX && handler) {
    handler.call(this, req, res);
  } else {
    res.writeHead(404);
  }
  res.end();
  util.puts('[api] ' + res.statusCode);
};

exports.ApiServlet = ApiServlet;
