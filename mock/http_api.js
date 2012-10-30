var url = require('url')
  , util = require('util')
  , sleep = require('./node_modules/sleep')
  ;


function ApiServlet(bayeuxBackend) {
  this._bayeuxBackend = bayeuxBackend;
}

ApiServlet.VERSION = [0, 0, 1];
VERSION_STR = ApiServlet.VERSION.join('.');
MOUNT_POINT = '/api/';
API_PREFIX = MOUNT_POINT + VERSION_STR + '/';

ApiServlet.HandlerMap = {
  reset: function(req, res) {
      res.writeHead(200);
      this._bayeuxBackend.resetModel();
      this._bayeuxBackend.publishSync();
    },
  passwordCreate: function(req, res) {
      var qs = url.parse(req.url, true).query;
      if (!qs.password) {
        res.writeHead(400);
      } else {
        res.writeHead(200);
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
        model.modal = model.setupComplete ? '' : 'welcome';
        this._bayeuxBackend.publishSync('modal');
        res.writeHead(200);
      } else {
        res.writeHead(403);
      }
    },
  'continue': function(req, res) {
      var model = this._bayeuxBackend.model;
      switch (model.modal) {
        case 'gtalkUnreachable':
          model.modal = model.setupComplete ?
                          '' :
                          (model.settings.mode == 'give' ?
                            'finished' :
                            'sysproxy');
          this._bayeuxBackend.publishSync('modal');
          res.writeHead(200);
          break;

        case 'firstInviteReceived':
          model.modal = model.settings.mode == 'get' ? 'sysproxy' : 'finished';
          this._bayeuxBackend.publishSync('modal');
          res.writeHead(200);
          break;

        case 'requestSent':
          model.modal = '';
          this._bayeuxBackend.publishSync('modal');
          res.writeHead(200);

        case 'finished':
          model.modal = '';
          model.setupComplete = true;
          this._bayeuxBackend.publishSync('setupComplete');
          this._bayeuxBackend.publishSync('modal');
          res.writeHead(200);
          break;
        
        default:
          res.writeHead(400);
      }
    },
  'settings/': function(req, res) {
      var model = this._bayeuxBackend.model
        , qs = url.parse(req.url, true).query
        , badRequest = false
        , mode = qs.mode
        , savePassword = qs.savePassword
        , systemProxy = qs.systemProxy
        , lang = qs.lang
        , autoReport = qs.autoReport
        , proxyAllSites = qs.proxyAllSites
        ;
      // XXX write this better
      if ('undefined' == typeof mode
       && 'undefined' == typeof savePassword
       && 'undefined' == typeof systemProxy
       && 'undefined' == typeof lang
       && 'undefined' == typeof autoReport
       && 'undefined' == typeof proxyAllSites
          ) {
        badRequest = true;
      } else {
        if (mode) {
          if (mode != 'give' && mode != 'get') {
            badRequest = true;
            util.puts('invalid value of mode: ' + mode);
          } else {
            if (model.settings.mode == 'give' && mode == 'get')
              sleep.usleep(750000);
            model.settings.mode = mode;
            if (!model.setupComplete)
              model.modal = 'signin';
          }
        }
        if (savePassword) {
          if (savePassword != 'true' && savePassword != 'false') {
            badRequest = true;
            util.puts('invalid value of savePassword: ' + savePassword);
          } else {
            savePassword = savePassword == 'true';
            model.settings.savePassword = savePassword;
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
            if (model.modal == 'sysproxy' && !model.setupComplete) {
              model.modal = 'finished';
            }
          }
        }
        if (lang) {
          if (lang != 'en' && lang != 'zh' && lang != 'fa' && lang != 'ar') {
            badRequest = true;
            util.puts('invalid value of lang: ' + lang);
          } else {
            model.settings.lang = lang;
          }
        }
        if (autoReport) {
          if (autoReport != 'true' && autoReport != 'false') {
            badRequest = true;
            util.puts('invalid value of autoReport: ' + autoReport);
          } else {
            autoReport = autoReport == 'true';
            model.settings.autoReport = autoReport;
          }
        }
        if (proxyAllSites) {
          if (proxyAllSites != 'true' && proxyAllSites != 'false') {
            badRequest = true;
            util.puts('invalid value of proxyAllSites: ' + proxyAllSites);
          } else {
            proxyAllSites = proxyAllSites == 'true';
            model.settings.proxyAllSites = proxyAllSites;
          }
        }
      }
      if (badRequest) {
        res.writeHead(400);
      } else {
        res.writeHead(200);
        this._bayeuxBackend.publishSync('settings');
        this._bayeuxBackend.publishSync('modal');
      }
    },
  signin: function(req, res) {
      var model = this._bayeuxBackend.model
        , qs = url.parse(req.url, true).query
        , userid = qs.userid
        , password = typeof qs.password != 'undefined' ?
                     qs.password :
                     (model.settings.passwordSaved ? 'password' : '')
        ;
      model.connectivity.gtalk = 'connecting';
      this._bayeuxBackend.publishSync('connectivity.gtalk');
      model.modal = 'signin';
      sleep.usleep(750000);
      if (!userid || !password) {
        res.writeHead(400);
        model.connectivity.gtalk = 'notConnected';
      } else {
        if (password != 'password') {
          res.writeHead(401);
          model.connectivity.gtalk = 'notConnected';
          model.settings.passwordSaved = false;
        } else if (userid == 'offline@example.com') {
          res.writeHead(503);
          model.modal = 'gtalkUnreachable';
          model.connectivity.gtalk = 'notConnected';
        } else if (userid == 'notinbeta@example.com') {
          res.writeHead(403);
          model.modal = 'notInvited';
          model.connectivity.gtalk = 'notConnected';
        } else {
          res.writeHead(200);
          model.connectivity.gtalk = 'connected';
          model.settings.userid = userid;
          if (model.settings.savePassword) {
            model.settings.passwordSaved = true;
          }
          if (model.setupComplete)
            model.modal = '';
          else
            model.modal = model.settings.mode == 'get' ? 'sysproxy' : 'finished';
        }
      }
      this._bayeuxBackend.publishSync('settings.savePassword');
      this._bayeuxBackend.publishSync('settings.passwordSaved');
      this._bayeuxBackend.publishSync('connectivity.gtalk');
      this._bayeuxBackend.publishSync('modal');
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
