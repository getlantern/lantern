var url = require('url')
  , util = require('util')
  , sleep = require('./node_modules/sleep')
  ;


function ApiServlet(bayeuxBackend) {
  this._bayeuxBackend = bayeuxBackend;
  ApiServlet._resetInternalState.call(this);
}

ApiServlet.VERSION = [0, 0, 1];
VERSION_STR = ApiServlet.VERSION.join('.');
MOUNT_POINT = '/api/';
API_PREFIX = MOUNT_POINT + VERSION_STR + '/';
CENSORING_COUNTRIES = {
    cn: 'China'
  , cu: 'Cuba'
  , ir: 'Iran'
  , mm: 'Myanmar'
  , sy: 'Syria'
  , tm: 'Turkmenistan'
  , uz: 'Uzbekistan'
  , vn: 'Vietnam'
  , bh: 'Bahrain'
  , by: 'Belarus'
  , sa: 'Saudi Arabia'
  , kp: 'North Korea'
  };

function inCensoringCountry(model) {
  return model.location.country in CENSORING_COUNTRIES;
}

var _lanternFriend1 = {
    "userid": "lantern_friend1@example.com",
    "ip":"74.120.12.135",
    "lat":51,
    "lon":9,
    "country":"de"
    }
, _lanternFriend2 = {
    "userid": "lantern_friend2@example.com",
    "ip":"93.182.129.82",
    "lat":13.1833,
    "lon":55.7,
    "country":"se"
  }
, _laeproxy1 = {
    "userid": "laeproxyhr1@appspot.com",
    "ip":"173.194.66.141",
    "lat":37.4192,
    "lon":-122.0574,
    "country":"us"
  }
;

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
  tryAnotherUser: 'tryAnotherUser',
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

var _modalSeqGive = [MODAL.inviteFriends, MODAL.finished, MODAL.none],
    _modalSeqGet = [MODAL.proxiedSites, MODAL.systemProxy].concat(_modalSeqGive);
/*
 * Show next modal that should be shown, or stop showing modal if none should
 * be shown. Only called after authorize modal has been completed.
 * Implemented like this since some modals can be skipped if the user is
 * unable to complete them, but should be returned to later.
 * */
ApiServlet._advanceModal = function() {
  var model = this._bayeuxBackend.model
    , modalSeq = inGiveMode(model) ? _modalSeqGive : _modalSeqGet
    , next;
  for (var i=0; this._internalState.modalsCompleted[next=modalSeq[i++]];);
  model.modal = next;
  util.puts('next modal: ' + next);
  this._bayeuxBackend.publishSync('modal');
};

ApiServlet._tryConnectPeers = function(model) {
  var userid = model.settings.userid;
  // check for lantern access
  switch (userid) {
    case 'user_invited@example.com':
      // has access, so we can connect to peers
      model.connectivity.peersCurrent = [_lanternFriend1, _laeproxy1];
      model.connectivity.peersLifetime = [_lanternFriend1, _laeproxy1, _lanternFriend2];
      this._bayeuxBackend.publishSync('connectivity.peersCurrent');
      this._bayeuxBackend.publishSync('connectivity.peersLifetime');
      util.puts("user has access, connected her to peers: "+util.inspect(model.connectivity.peersCurrent));
      return;

    case 'user_cant_reach_gtalk@example.com':
      model.modal = MODAL.gtalkUnreachable;
      this._bayeuxBackend.publishSync('modal');
      util.puts("user can't reach google talk, set modal to "+MODAL.gtalkUnreachable);
      return;

    default:
      // assume user does not have access
      model.modal = MODAL.notInvited;
      this._bayeuxBackend.publishSync('modal');
      util.puts("user does not have access, set modal to "+MODAL.notInvited);
      return;
  }
};

ApiServlet.HandlerMap = {
  reset: function(req, res) {
      ApiServlet._resetInternalState.call(this);
      this._bayeuxBackend.resetModel();
      this._bayeuxBackend.publishSync();
      res.writeHead(200);
    },
  passwordCreate: function(req, res) {
      var model = this._bayeuxBackend.model
        , qs = url.parse(req.url, true).query;
      if (!validatePasswords(qs.password1, qs.password2)) {
        res.writeHead(400);
      } else {
        res.writeHead(200);
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
        res.writeHead(200);
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
          res.writeHead(200);
          return;

        case MODAL.giveModeForbidden:
          if (interaction != INTERACTION.cancel) {
            res.writeHead(400);
            return;
          }
          model.modal = this._internalState.modalsCompleted[MODAL.welcome] ?
                          MODAL.settings : MODAL.welcome;
          this._bayeuxBackend.publishSync('modal');
          res.writeHead(200);
          return;

        case MODAL.proxiedSites:
          if (interaction != INTERACTION.continue) {
            res.writeHead(400);
            return;
          }
          this._internalState.modalsCompleted[MODAL.proxiedSites] = true;
          ApiServlet._advanceModal.call(this);
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
          ApiServlet._advanceModal.call(this);
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
            model.modal = MODAL.authorize;
            this._bayeuxBackend.publishSync('modal');
          } else if (interaction == INTERACTION.retryLater) {
            model.modal = MODAL.authorizeLater;
            this._bayeuxBackend.publishSync('modal');
          } else {
            res.writeHead(400);
            return;
          }
          res.writeHead(200);
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

        /*
        XXX
        case MODAL.firstInviteReceived:
          model.modal = model.settings.mode == 'get' ? 'sysproxy' : 'finished';
          this._bayeuxBackend.publishSync('modal');
          res.writeHead(200);
          break;

        case MODAL.requestSent:
          model.modal = MODAL.none;
          this._bayeuxBackend.publishSync('modal');
          res.writeHead(200);
        */

        case MODAL.finished:
          if (interaction != INTERACTION.continue) {
            res.writeHead(400);
            return;
          }
          this._internalState.modalsCompleted[MODAL.finished] = true;
          ApiServlet._advanceModal.call(this);
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
            if (inGiveMode(model) && interaction == MODE.get && model.settings.systemProxy)
              sleep.usleep(750000);
            model.settings.mode = interaction;
            this._bayeuxBackend.publishSync('settings.mode');
            ApiServlet._advanceModal.call(this);
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
          res.writeHead(200);
          return;

        case MODAL.about:
        case MODAL.updateAvailable:
        case MODAL.confirmReset:
          if (interaction == INTERACTION.close) {
            model.modal = MODAL.none;
            this._bayeuxBackend.publishSync('modal');
            res.writeHead(200);
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
        , advertiseLantern = qs.advertiseLantern
        ;
      // XXX write this better
      if ('undefined' == typeof mode
       && 'undefined' == typeof systemProxy
       && 'undefined' == typeof lang
       && 'undefined' == typeof autoReport
       && 'undefined' == typeof autoStart
       && 'undefined' == typeof proxyAllSites
       && 'undefined' == typeof proxiedSites
       && 'undefined' == typeof advertiseLantern
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
        if (advertiseLantern) {
          if (advertiseLantern != 'true' && advertiseLantern != 'false') {
            badRequest = true;
            util.puts('invalid value of advertiseLantern: ' + advertiseLantern);
          } else {
            advertiseLantern = advertiseLantern == 'true';
            model.settings.advertiseLantern = advertiseLantern;
            this._bayeuxBackend.publishSync('settings.advertiseLantern');
          }
        }
      }
      if (badRequest) {
        res.writeHead(400);
      } else {
        res.writeHead(200);
      }
    },
  oauthAuthorized: function(req, res) {
      var model = this._bayeuxBackend.model
        , qs = url.parse(req.url, true).query 
        , userid = qs.userid
        ;
      model.settings.userid = userid;
      this._bayeuxBackend.publishSync('settings.userid');
      model.connectivity.gtalk = CONNECTIVITY.connected;
      this._bayeuxBackend.publishSync('connectivity.gtalk');
      model.connectivity.gtalkAuthorized = true;
      this._bayeuxBackend.publishSync('connectivity.gtalkAuthorized');
      this._internalState.modalsCompleted[MODAL.authorize] = true;
      ApiServlet._advanceModal.call(this);
      ApiServlet._tryConnectPeers.call(this, model);
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
      res.writeHead(200);
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
