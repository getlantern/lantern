#!/usr/bin/env node

var sys = require('sys'),
    http = require('http'),
    fs = require('fs'),
    url = require('url'),
    events = require('events'),
    sleep = require('../node_modules/sleep'),
    faye = require('../node_modules/faye');

//faye.Logging.logLevel = faye.Logging.LOG_LEVELS.info;

var DEFAULT_PORT = 8000;

function main(argv) {
  new HttpServer({
    'GET': createServlet(StaticServlet),
    'HEAD': createServlet(StaticServlet),
    'POST': createServlet(ApiServlet)
  }).start(Number(argv[2]) || DEFAULT_PORT);
}

function escapeHtml(value) {
  return value.toString().
    replace('<', '&lt;').
    replace('>', '&gt;').
    replace('"', '&quot;');
}

function createServlet(Class) {
  var servlet = new Class();
  return servlet.handleRequest.bind(servlet);
}

// XXX
var bayeux,
    model;
function resetModel() {
  model = {
    modal: 'welcome',
    lang: 'en',
    connectivity: {
      internet: true,
      gtalk: 'notConnected',
      peers: 0
    },
    settings: {
      savePassword: true,
      passwordSaved: false,
      startAtLogin: true,
      autoReport: true,
      proxyPort: 8787,
      proxyAllSites: false,
      proxiedSitesList: [
        'google.com',
        'twitter.com'
        ]
    }
  };
}
resetModel();
function sync(obj, path, value){
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

/**
 * An Http server implementation that uses a map of methods to decide
 * action routing.
 *
 * @param {Object} Map of method => Handler function
 */
function HttpServer(handlers) {
  this.handlers = handlers;
  this.server = http.createServer(this.handleRequest_.bind(this));
  bayeux = new faye.NodeAdapter({mount: '/cometd', timeout: 45});
  bayeux.attach(this.server);
}

HttpServer.prototype.start = function(port) {
  this.port = port;
  this.server.listen(port, '0.0.0.0');
  sys.puts('Bayeux-attached http server running at http://0.0.0.0:'+port);
  sys.puts('Lantern UI running at http://0.0.0.0:'+port+'/app/index.html');

  bayeux.bind('handshake', function(clientId) {
    sys.puts('[bayeux] handshake: client: ' + clientId);
  });
  bayeux.bind('subscribe', function(clientId, channel) {
    sys.puts('[bayeux] subscribe: client: ' + clientId + ', channel: ' + channel);
    sys.puts('[bayeux]            publishing entire state to /sync channel');
    bayeux._server._engine.publish({channel:'/sync', data:{path:'', value:model}});
  });
  bayeux.bind('unsubscribe', function(clientId, channel) {
    sys.puts('[bayeux] unsubscribe: client ' + clientId + ', channel ' + channel);
  });
  bayeux.bind('publish', function(clientId, channel, data) {
    sys.puts('[bayeux] got publish: ' + clientId + ' ' + channel + ' ' + sys.inspect(data));
    if (channel == '/sync' && typeof clientId != 'undefined') {
      sys.puts('[bayeux] syncing client publication: client:' + clientId + ', data:\n' + sys.inspect(data));
      sync(model, data.path, data.value);
    }
  });
  bayeux.bind('disconnect', function(clientId) {
    sys.puts('[bayeux] disconnect: client ' + clientId);
  });
};

HttpServer.prototype.parseUrl_ = function(urlString) {
  var parsed = url.parse(urlString);
  parsed.pathname = url.resolve('/', parsed.pathname);
  return url.parse(url.format(parsed), true);
};

HttpServer.prototype.handleRequest_ = function(req, res) {
  /*
  var logEntry = req.method + ' ' + req.url;
  if (req.headers['user-agent']) {
    logEntry += ' ' + req.headers['user-agent'];
  }
  logEntry = '[http] ' + logEntry;
  sys.puts(logEntry);
  */
  req.url = this.parseUrl_(req.url);
  var handler = this.handlers[req.method];
  if (!handler) {
    res.writeHead(501);
    res.end();
  } else {
    handler.call(this, req, res);
  }
};

/**
 * Mock Dashboard API
 */
function ApiServlet() {}

ApiServlet.HandlerMap = {
  '/api/0.0.1/reset': function(req, res, parsed) {
      res.writeHead(200);
      resetModel();
      bayeux._server._engine.publish({channel:'/sync', data:{path:'', value:model}});
    },
  '/api/0.0.1/passwordCreate': function(req, res, parsed) {
      if (!parsed.query.password) {
        res.writeHead(400);
      } else {
        res.writeHead(200);
      }
    },
  '/api/0.0.1/settings/unlock': function(req, res, parsed) {
      var password = parsed.query.password;
      if (!parsed.query.password) {
        res.writeHead(400);
      } else if (parsed.query.password == 'password') {
        res.writeHead(200);
      } else {
        res.writeHead(403);
      }
    },
  '/api/0.0.1/continue': function(req, res, parsed) {
      switch (model.modal) {
        case 'gtalkUnreachable':
          model.modal = model.setupComplete ?
                          '' :
                          (model.settings.mode == 'give' ?
                            'finished' :
                            'sysproxy');
          bayeux._server._engine.publish({channel:'/sync', data:{path:'modal', value:model.modal}});
          res.writeHead(200);
          break;

        case 'firstInviteReceived':
          model.modal = model.settings.mode == 'get' ? 'sysproxy' : 'finished';
          bayeux._server._engine.publish({channel:'/sync', data:{path:'modal', value:model.modal}});
          res.writeHead(200);
          break;

        case 'requestSent':
          model.modal = '';
          bayeux._server._engine.publish({channel:'/sync', data:{path:'modal', value:model.modal}});
          res.writeHead(200);

        case 'finished':
          model.modal = '';
          model.setupComplete = true;
          bayeux._server._engine.publish({channel:'/sync', data:{path:'', value:model}});
          res.writeHead(200);
          break;
        
        default:
          res.writeHead(400);
      }
    },
  '/api/0.0.1/settings/': function(req, res, parsed) {
      var mode = parsed.query.mode,
          savePassword = parsed.query.savePassword,
          systemProxy = parsed.query.systemProxy,
          lang = parsed.query.lang,
          badRequest = false;
      if ('undefined' == typeof mode
       && 'undefined' == typeof savePassword
       && 'undefined' == typeof systemProxy
       && 'undefined' == typeof lang
          ) {
        badRequest = true;
      } else {
        if (mode) {
          if (mode != 'give' && mode != 'get') {
            badRequest = true;
            sys.puts('invalid value of mode: ' + mode);
          } else {
            model.settings.mode = mode;
            if (!model.settings.setupComplete)
              model.modal = 'signin';
          }
        }
        if (savePassword) {
          if (savePassword != 'true' && savePassword != 'false') {
            badRequest = true;
            sys.puts('invalid value of savePassword: ' + savePassword);
          } else {
            savePassword = savePassword == 'true';
            model.settings.savePassword = savePassword;
          }
        }
        if (systemProxy) {
          if (systemProxy != 'true' && systemProxy != 'false') {
            badRequest = true;
            sys.puts('invalid value of systemProxy: ' + systemProxy);
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
            sys.puts('invalid value of lang: ' + lang);
          } else {
            model.settings.lang = lang;
          }
        }
      }
      if (badRequest) {
        res.writeHead(400);
      } else {
        res.writeHead(200);
        bayeux._server._engine.publish({channel:'/sync', data:{path:'', value:model}});
      }
    },
  '/api/0.0.1/signin': function(req, res, parsed) {
      var userid = parsed.query.userid,
          password = typeof parsed.query.password != 'undefined' ?
                     parsed.query.password :
                     (model.settings.passwordSaved ? 'password' : '');
      model.connectivity.gtalk = 'connecting';
      bayeux._server._engine.publish({channel:'/sync', data:{path:'connectivity.gtalk', value:model.connectivity.gtalk}});
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
      bayeux._server._engine.publish({channel:'/sync', data:{path:'', value:model}});
    },
  '/api/0.0.1/requestInvite': function(req, res, parsed) {
      var lanternDevs = parsed.query.lanternDevs;
      if (typeof lanternDevs != 'undefined'
          && lanternDevs != 'true'
          && lanternDevs != 'false') {
        res.writeHead(400);
      }
      sleep.usleep(750000);
      model.modal = 'requestSent';
      bayeux._server._engine.publish({channel:'/sync', data:{path:'modal', value:model.modal}});
      res.writeHead(200);
    }
};

ApiServlet.prototype.handleRequest = function(req, res) {
  var self = this,
      parsed = url.parse(req.url, true),
      handler = ApiServlet.HandlerMap[parsed.pathname];
  if (handler) {
    handler(req, res, parsed);
  } else {
    res.writeHead(404);
  }
  res.end();
  sys.puts('[api] ' + req.url.href + ' ' + res.statusCode);
};

/**
 * Handles static content.
 */
function StaticServlet() {}

StaticServlet.MimeMap = {
  'txt': 'text/plain',
  'html': 'text/html',
  'css': 'text/css',
  'xml': 'application/xml',
  'json': 'application/json',
  'js': 'application/javascript',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'gif': 'image/gif',
  'png': 'image/png'
};

StaticServlet.prototype.handleRequest = function(req, res) {
  var self = this;
  var path = ('./' + req.url.pathname).replace('//','/').replace(/%(..)/, function(match, hex){
    return String.fromCharCode(parseInt(hex, 16));
  });
  var parts = path.split('/');
  if (parts[parts.length-1].charAt(0) === '.')
    return self.sendForbidden_(req, res, path);
  fs.stat(path, function(err, stat) {
    if (err)
      return self.sendMissing_(req, res, path);
    if (stat.isDirectory())
      return self.sendDirectory_(req, res, path);
    return self.sendFile_(req, res, path);
  });
}

StaticServlet.prototype.sendError_ = function(req, res, error) {
  res.writeHead(500, {
      'Content-Type': 'text/html'
  });
  res.write('<!doctype html>\n');
  res.write('<title>Internal Server Error</title>\n');
  res.write('<h1>Internal Server Error</h1>');
  res.write('<pre>' + escapeHtml(sys.inspect(error)) + '</pre>');
  sys.puts('500 Internal Server Error');
  sys.puts(sys.inspect(error));
};

StaticServlet.prototype.sendMissing_ = function(req, res, path) {
  path = path.substring(1);
  res.writeHead(404, {
      'Content-Type': 'text/html'
  });
  res.write('<!doctype html>\n');
  res.write('<title>404 Not Found</title>\n');
  res.write('<h1>Not Found</h1>');
  res.write(
    '<p>The requested URL ' +
    escapeHtml(path) +
    ' was not found on this server.</p>'
  );
  res.end();
  sys.puts('404 Not Found: ' + path);
};

StaticServlet.prototype.sendForbidden_ = function(req, res, path) {
  path = path.substring(1);
  res.writeHead(403, {
      'Content-Type': 'text/html'
  });
  res.write('<!doctype html>\n');
  res.write('<title>403 Forbidden</title>\n');
  res.write('<h1>Forbidden</h1>');
  res.write(
    '<p>You do not have permission to access ' +
    escapeHtml(path) + ' on this server.</p>'
  );
  res.end();
  sys.puts('403 Forbidden: ' + path);
};

StaticServlet.prototype.sendRedirect_ = function(req, res, redirectUrl) {
  res.writeHead(301, {
      'Content-Type': 'text/html',
      'Location': redirectUrl
  });
  res.write('<!doctype html>\n');
  res.write('<title>301 Moved Permanently</title>\n');
  res.write('<h1>Moved Permanently</h1>');
  res.write(
    '<p>The document has moved <a href="' +
    redirectUrl +
    '">here</a>.</p>'
  );
  res.end();
  sys.puts('301 Moved Permanently: ' + redirectUrl);
};

StaticServlet.prototype.sendFile_ = function(req, res, path) {
  var self = this;
  var file = fs.createReadStream(path);
  res.writeHead(200, {
    'Content-Type': StaticServlet.
      MimeMap[path.split('.').pop()] || 'text/plain'
  });
  if (req.method === 'HEAD') {
    res.end();
  } else {
    file.on('data', res.write.bind(res));
    file.on('close', function() {
      res.end();
    });
    file.on('error', function(error) {
      self.sendError_(req, res, error);
    });
  }
};

StaticServlet.prototype.sendDirectory_ = function(req, res, path) {
  var self = this;
  if (path.match(/[^\/]$/)) {
    req.url.pathname += '/';
    var redirectUrl = url.format(url.parse(url.format(req.url)));
    return self.sendRedirect_(req, res, redirectUrl);
  }
  fs.readdir(path, function(err, files) {
    if (err)
      return self.sendError_(req, res, error);

    if (!files.length)
      return self.writeDirectoryIndex_(req, res, path, []);

    var remaining = files.length;
    files.forEach(function(fileName, index) {
      fs.stat(path + '/' + fileName, function(err, stat) {
        if (err)
          return self.sendError_(req, res, err);
        if (stat.isDirectory()) {
          files[index] = fileName + '/';
        }
        if (!(--remaining))
          return self.writeDirectoryIndex_(req, res, path, files);
      });
    });
  });
};

StaticServlet.prototype.writeDirectoryIndex_ = function(req, res, path, files) {
  path = path.substring(1);
  res.writeHead(200, {
    'Content-Type': 'text/html'
  });
  if (req.method === 'HEAD') {
    res.end();
    return;
  }
  res.write('<!doctype html>\n');
  res.write('<title>' + escapeHtml(path) + '</title>\n');
  res.write('<style>\n');
  res.write('  ol { list-style-type: none; font-size: 1.2em; }\n');
  res.write('</style>\n');
  res.write('<h1>Directory: ' + escapeHtml(path) + '</h1>');
  res.write('<ol>');
  files.forEach(function(fileName) {
    if (fileName.charAt(0) !== '.') {
      res.write('<li><a href="' +
        escapeHtml(fileName) + '">' +
        escapeHtml(fileName) + '</a></li>');
    }
  });
  res.write('</ol>');
  res.end();
};

// Must be last,
main(process.argv);
