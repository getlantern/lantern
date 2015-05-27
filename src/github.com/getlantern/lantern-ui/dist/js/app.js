'use strict';

var app = angular.module('app', [
  'app.constants',
  'ngWebSocket',
  'LocalStorageModule',
  'app.helpers',
  'pascalprecht.translate',
  'app.filters',
  'app.services',
  'app.directives',
  'app.vis',
  'ngSanitize',
  'ngResource',
  'ui.utils',
  'ui.showhide',
  'ui.validate',
  'ui.bootstrap',
  'ui.bootstrap.tpls'
  ])
  .directive('dynamic', function ($compile) {
    return {
      restrict: 'A',
      replace: true,
      link: function (scope, ele, attrs) {
        scope.$watch(attrs.dynamic, function(html) {
          ele.html(html);
          $compile(ele.contents())(scope);
        });
      }
    };
  })
  .config(function($tooltipProvider, $httpProvider,
                   $resourceProvider, $translateProvider, DEFAULT_LANG) {

      $translateProvider.preferredLanguage(DEFAULT_LANG);

      $translateProvider.useStaticFilesLoader({
          prefix: './locale/',
          suffix: '.json'
      });
    $httpProvider.defaults.useXDomain = true;
    delete $httpProvider.defaults.headers.common["X-Requested-With"];
    //$httpProvider.defaults.headers.common['X-Requested-With'] = 'XMLHttpRequest';
    $tooltipProvider.options({
      appendToBody: true
    });
  })
  // angular-ui config
  .value('ui.config', {
    animate: 'ui-hide',
  })
  // split array displays separates an array inside a textarea with newlines
  .directive('splitArray', function() {
      return {
          restrict: 'A',
          require: 'ngModel',
          link: function(scope, element, attr, ngModel) {

              function fromUser(text) {
                  return text.split("\n");
              }

              function toUser(array) {
                  if (array) {
                    return array.join("\n");
                  }
              }

              ngModel.$parsers.push(fromUser);
              ngModel.$formatters.push(toUser);
          }
      };
  })
  .factory('DataStream', [
    '$websocket',
    '$rootScope',
    '$interval',
    '$window',
    'Messages',
    function($websocket, $rootScope, $interval, $window, Messages) {

      var WS_RECONNECT_INTERVAL = 5000;
      var WS_RETRY_COUNT        = 0;

      var ds = $websocket('ws://' + document.location.host + '/data');

      ds.onMessage(function(raw) {
        var envelope = JSON.parse(raw.data);
        if (typeof Messages[envelope.Type] != 'undefined') {
          Messages[envelope.Type].call(this, envelope.Message);
        } else {
          console.log('Got unknown message type: ' + envelope.Type);
        };
      });

      ds.onOpen(function(msg) {
        $rootScope.wsConnected = true;
        WS_RETRY_COUNT = 0;
        $rootScope.backendIsGone = false;
        $rootScope.wsLastConnectedAt = new Date();
        console.log("New websocket instance created " + msg);
      });

      ds.onClose(function(msg) {
        $rootScope.wsConnected = false;
        // try to reconnect indefinitely
        // when the websocket closes
        $interval(function() {
          console.log("Trying to reconnect to disconnected websocket");
          ds = $websocket('ws://' + document.location.host + '/data');
          ds.onOpen(function(msg) {
            $window.location.reload();
          });
        }, WS_RECONNECT_INTERVAL);
        console.log("This websocket instance closed " + msg);
      });

      ds.onError(function(msg) {
          console.log("Error on this websocket instance " + msg);
      });

      var methods = {
        'send': function(messageType, data) {
          console.log('request to send.');
          ds.send(JSON.stringify({'Type': messageType, 'Message': data}))
        }
      };

      return methods;
    }
  ])
  .factory('ProxiedSites', ['$window', '$rootScope', 'DataStream', function($window, $rootScope, DataStream) {

      var methods = {
        update: function() {
          console.log('UPDATE');
          // dataStream.send(JSON.stringify($rootScope.updates));
          DataStream.send('ProxiedSites', $rootScope.updates)
        },
        get: function() {
          console.log('GET');
          // dataStream.send(JSON.stringify({ action: 'get' }));
          DataStream.send('ProxiedSites', {'action': 'get'});
        }
      };

      return methods;
  }])
  .run(function ($filter, $log, $rootScope, $timeout, $window, $websocket,
                 $translate, $http, apiSrvc, gaMgr, modelSrvc, ENUMS, EXTERNAL_URL, MODAL, CONTACT_FORM_MAXLEN) {

    var CONNECTIVITY = ENUMS.CONNECTIVITY,
        MODE = ENUMS.MODE,
        jsonFltr = $filter('json'),
        model = modelSrvc.model,
        prettyUserFltr = $filter('prettyUser'),
        reportedStateFltr = $filter('reportedState');

    // for easier inspection in the JavaScript console
    $window.rootScope = $rootScope;
    $window.model = model;

    $rootScope.EXTERNAL_URL = EXTERNAL_URL;

    $rootScope.model = model;
    $rootScope.DEFAULT_AVATAR_URL = 'img/default-avatar.png';
    $rootScope.CONTACT_FORM_MAXLEN = CONTACT_FORM_MAXLEN;

    angular.forEach(ENUMS, function(val, key) {
      $rootScope[key] = val;
    });

    $rootScope.reload = function () {
      location.reload(true); // true to bypass cache and force request to server
    };

    $rootScope.switchLang = function (lang) {
        $rootScope.lang = lang;
        $translate.use(lang);
    };

    $rootScope.trackPageView = function() {
        gaMgr.trackPageView('start');
    };

    $rootScope.valByLang = function(name) {
        // use language-specific forums URL
        if (name && $rootScope.lang && 
            name.hasOwnProperty($rootScope.lang)) {
            return name[$rootScope.lang];
        }
        // default to English language forum
        return name['en_US'];
    };

    $rootScope.changeLang = function(lang) {
      return $rootScope.interaction(INTERACTION.changeLang, {lang: lang});
    };

    $rootScope.openRouterConfig = function() {
      return $rootScope.interaction(INTERACTION.routerConfig);
    };

    $rootScope.openExternal = function(url) {
      return $window.open(url);
    };

    $rootScope.resetContactForm = function (scope) {
      if (scope.show) {
        var reportedState = jsonFltr(reportedStateFltr(model));
        scope.diagnosticInfo = reportedState;
      }
    };

    $rootScope.interactionWithNotify = function (interactionid, scope, reloadAfter) {
      var extra;
      if (scope.notify) {
        var diagnosticInfo = scope.diagnosticInfo;
        if (diagnosticInfo) {
          try {
            diagnosticInfo = angular.fromJson(diagnosticInfo);
          } catch (e) {
            $log.debug('JSON decode diagnosticInfo', diagnosticInfo, 'failed, passing as-is');
          }
        }
        extra = {
          context: model.modal,
          message: scope.message,
          diagnosticInfo: diagnosticInfo
        };
      }
      $rootScope.interaction(interactionid, extra).then(function () {
        if (reloadAfter) $rootScope.reload();
      });
    };

    $rootScope.backendIsGone = false;
    $rootScope.$watch("wsConnected", function(wsConnected) {
      var MILLIS_UNTIL_BACKEND_CONSIDERED_GONE = 10000;
      if (!wsConnected) {
        // In 11 seconds, check if we're still not connected
        $timeout(function() {
          var lastConnectedAt = $rootScope.wsLastConnectedAt;
          if (lastConnectedAt) {
            var timeSinceLastConnected = new Date().getTime() - lastConnectedAt.getTime();
            $log.debug("Time since last connect", timeSinceLastConnected);
            if (timeSinceLastConnected > MILLIS_UNTIL_BACKEND_CONSIDERED_GONE) {
              // If it's been more than 10 seconds since we last connect,
              // treat the backend as gone
              console.log("Backend is gone");
              $rootScope.backendIsGone = true;
            } else {
              $rootScope.backendIsGone = false;
            }
          }
        }, MILLIS_UNTIL_BACKEND_CONSIDERED_GONE + 1);
      }
    });
  });

'use strict';

function makeEnum(keys, extra) {
  var obj = {};
  for (var i=0, key=keys[i]; key; key=keys[++i]) {
    obj[key] = key;
  }
  if (extra) {
    for (var key in extra)
      obj[key] = extra[key];
  }
  return obj;
}

var DEFAULT_LANG = 'en_US',
    DEFAULT_DIRECTION = 'ltr',
    LANGS = {
      // http://www.omniglot.com/language/names.htm
      en_US: {dir: 'ltr', name: 'English'},
      de: {dir: 'ltr', name: 'Deutsch'},
      fr_FR: {dir: 'ltr', name: 'français (France)'},
      fr_CA: {dir: 'ltr', name: 'français (Canada)'},
      ca: {dir: 'ltr', name: 'català'},
      pt_BR: {dir: 'ltr', name: 'português'},
      fa_IR: {dir: 'rtl', name: 'پارسی'},
      zh_CN: {dir: 'ltr', name: '中文'},
      nl: {dir: 'ltr', name: 'Nederlands'},
      sk: {dir: 'ltr', name: 'slovenčina'},
      cs: {dir: 'ltr', name: 'čeština'},
      sv: {dir: 'ltr', name: 'Svenska'},
      ja: {dir: 'ltr', name: '日本語'},
      uk: {dir: 'ltr', name: 'Українська (діаспора)'},
      uk_UA: {dir: 'ltr', name: 'Українська (Україна)'},
      ru_RU: {dir: 'ltr', name: 'Русский язык'},
      es: {dir: 'ltr', name: 'español'},
      ar: {dir: 'rtl', name: 'العربية'}
    },
    GOOGLE_ANALYTICS_WEBPROP_ID = 'UA-21815217-2',
    GOOGLE_ANALYTICS_DISABLE_KEY = 'ga-disable-'+GOOGLE_ANALYTICS_WEBPROP_ID,
    loc = typeof location == 'object' ? location : undefined,
    // this allows the real backend to mount the entire app under a random path
    // for security while the mock backend can always use '/app':
    APP_MOUNT_POINT = loc ? loc.pathname.split('/')[1] : 'app',
    API_MOUNT_POINT = 'api',
    COMETD_MOUNT_POINT = 'cometd',
    COMETD_URL = loc && loc.protocol+'//'+loc.host+'/'+APP_MOUNT_POINT+'/'+COMETD_MOUNT_POINT,
    REQUIRED_API_VER = {major: 0, minor: 0}, // api version required by frontend
    REQ_VER_STR = [REQUIRED_API_VER.major, REQUIRED_API_VER.minor].join('.'),
    API_URL_PREFIX = ['', APP_MOUNT_POINT, API_MOUNT_POINT, REQ_VER_STR].join('/'),
    MODEL_SYNC_CHANNEL = '/sync',
    CONTACT_FORM_MAXLEN = 500000,
    INPUT_PAT = {
      // based on http://www.regular-expressions.info/email.html
      EMAIL: /^[a-zA-Z0-9._%+-]+@(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$/,
      EMAIL_INSIDE: /[a-zA-Z0-9._%+-]+@(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}/,
      // from http://html5pattern.com/
      DOMAIN: /^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,6}$/,
      IPV4: /((^|\.)((25[0-5])|(2[0-4]\d)|(1\d\d)|([1-9]?\d))){4}$/
    },
    EXTERNAL_URL = {
      rally: 'https://rally.org/lantern/donate',
      cloudServers: 'https://github.com/getlantern/lantern/wiki/Lantern-Cloud-Servers',
      autoReportPrivacy: 'https://github.com/getlantern/lantern/wiki/Privacy#wiki-optional-information',
      homepage: 'https://www.getlantern.org/',
      userForums: {
        en_US: 'https://groups.google.com/group/lantern-users-en',
        fr_FR: 'https://groups.google.com/group/lantern-users-fr',
        fr_CA: 'https://groups.google.com/group/lantern-users-fr',
        ar: 'https://groups.google.com/group/lantern-users-ar',
        fa_IR: 'https://groups.google.com/group/lantern-users-fa',
        zh_CN: 'https://lanternforum.greatfire.org/'
      },
      docs: 'https://github.com/getlantern/lantern/wiki',
      getInvolved: 'https://github.com/getlantern/lantern/wiki/Get-Involved',
      proxiedSitesWiki: 'https://github.com/getlantern/lantern-proxied-sites-lists/wiki',
      developers: 'https://github.com/getlantern/lantern'
    },
    // enums
    MODE = makeEnum(['give', 'get', 'unknown']),
    OS = makeEnum(['windows', 'linux', 'osx']),
    MODAL = makeEnum([
      'settingsLoadFailure',
      'unexpectedState', // frontend only
      'welcome',
      'authorize',
      'connecting',
      'notInvited',
      'proxiedSites',
      'lanternFriends',
      'finished',
      'contact',
      'settings',
      'confirmReset',
      'giveModeForbidden',
      'about',
      'sponsor',
      'sponsorToContinue',
      'updateAvailable',
      'scenarios'],
      {none: ''}),
    INTERACTION = makeEnum([
      'changeLang',
      'give',
      'get',
      'set',
      'lanternFriends',
      'friend',
      'reject',
      'contact',
      'settings',
      'reset',
      'proxiedSites',
      'about',
      'sponsor',
      'updateAvailable',
      'retry',
      'cancel',
      'continue',
      'close',
      'quit',
      'refresh',
      'unexpectedStateReset',
      'unexpectedStateRefresh',
      'url',
      'developer',
      'scenarios',
      'routerConfig']),
    SETTING = makeEnum([
      'lang',
      'mode',
      'autoReport',
      'runAtSystemStart',
      'systemProxy',
      'proxyAllSites',
      'proxyPort',
      'proxiedSites']),
    PEER_TYPE = makeEnum([
      'pc',
      'cloud',
      'laeproxy'
      ]),
    FRIEND_STATUS = makeEnum([
      'friend',
      'pending',
      'rejected'
      ]),
    CONNECTIVITY = makeEnum([
      'notConnected',
      'connecting',
      'connected']),
    GTALK_STATUS = makeEnum([
      'offline',
      'unavailable',
      'idle',
      'available']),
    SUGGESTION_REASON = makeEnum([
      'runningLantern',
      'friendedYou'
      ]),
    ENUMS = {
      MODE: MODE,
      OS: OS,
      MODAL: MODAL,
      INTERACTION: INTERACTION,
      SETTING: SETTING,
      PEER_TYPE: PEER_TYPE,
      FRIEND_STATUS: FRIEND_STATUS,
      CONNECTIVITY: CONNECTIVITY,
      GTALK_STATUS: GTALK_STATUS,
      SUGGESTION_REASON: SUGGESTION_REASON
    };

if (typeof angular == 'object' && angular && typeof angular.module == 'function') {
  angular.module('app.constants', [])
    .constant('DEFAULT_LANG', DEFAULT_LANG)
    .constant('DEFAULT_DIRECTION', DEFAULT_DIRECTION)
    .constant('LANGS', LANGS)
    .constant('API_MOUNT_POINT', API_MOUNT_POINT)
    .constant('APP_MOUNT_POINT', APP_MOUNT_POINT)
    .constant('COMETD_MOUNT_POINT', COMETD_MOUNT_POINT)
    .constant('COMETD_URL', COMETD_URL)
    .constant('MODEL_SYNC_CHANNEL', MODEL_SYNC_CHANNEL)
    .constant('CONTACT_FORM_MAXLEN', CONTACT_FORM_MAXLEN)
    .constant('INPUT_PAT', INPUT_PAT)
    .constant('EXTERNAL_URL', EXTERNAL_URL)
    .constant('ENUMS', ENUMS)
    .constant('MODE', MODE)
    .constant('OS', OS)
    .constant('MODAL', MODAL)
    .constant('INTERACTION', INTERACTION)
    .constant('SETTING', SETTING)
    .constant('PEER_TYPE', PEER_TYPE)
    .constant('FRIEND_STATUS', FRIEND_STATUS)
    .constant('CONNECTIVITY', CONNECTIVITY)
    .constant('GTALK_STATUS', GTALK_STATUS)
    .constant('SUGGESTION_REASON', SUGGESTION_REASON)
    // frontend-only
    .constant('GOOGLE_ANALYTICS_WEBPROP_ID', GOOGLE_ANALYTICS_WEBPROP_ID)
    .constant('GOOGLE_ANALYTICS_DISABLE_KEY', GOOGLE_ANALYTICS_DISABLE_KEY)
    .constant('LANTERNUI_VER', window.LANTERNUI_VER) // set in version.js
    .constant('REQUIRED_API_VER', REQUIRED_API_VER)
    .constant('API_URL_PREFIX', API_URL_PREFIX);
} else if (typeof exports == 'object' && exports && typeof module == 'object' && module && module.exports == exports) {
  module.exports = {
    DEFAULT_LANG: DEFAULT_LANG,
    DEFAULT_DIRECTION: DEFAULT_DIRECTION,
    LANGS: LANGS,
    API_MOUNT_POINT: API_MOUNT_POINT,
    APP_MOUNT_POINT: APP_MOUNT_POINT,
    COMETD_MOUNT_POINT: COMETD_MOUNT_POINT,
    COMETD_URL: COMETD_URL,
    MODEL_SYNC_CHANNEL: MODEL_SYNC_CHANNEL,
    CONTACT_FORM_MAXLEN: CONTACT_FORM_MAXLEN,
    INPUT_PAT: INPUT_PAT,
    EXTERNAL_URL: EXTERNAL_URL,
    ENUMS: ENUMS,
    MODE: MODE,
    OS: OS,
    MODAL: MODAL,
    INTERACTION: INTERACTION,
    SETTING: SETTING,
    PEER_TYPE: PEER_TYPE,
    FRIEND_STATUS: FRIEND_STATUS,
    CONNECTIVITY: CONNECTIVITY,
    GTALK_STATUS: GTALK_STATUS,
    SUGGESTION_REASON: SUGGESTION_REASON
  };
}

'use strict';

if (typeof inspect != 'function') {
  try {
    var inspect = require('util').inspect;
  } catch (e) {
    var inspect = function(x) { return JSON.stringify(x); };
  }
}

if (typeof _ != 'function') {
  var _ = require('../bower_components/lodash/lodash.min.js')._;
}

if (typeof jsonpatch != 'object') {
  var jsonpatch = require('../bower_components/jsonpatch/lib/jsonpatch.js');
}
var JSONPatch = jsonpatch.JSONPatch,
    JSONPointer = jsonpatch.JSONPointer,
    PatchApplyError = jsonpatch.PatchApplyError,
    InvalidPatch = jsonpatch.InvalidPatch;

function makeLogger(prefix) {
  return function() {
    var s = '[' + prefix + '] ';
    for (var i=0, l=arguments.length, ii=arguments[i]; i<l; ii=arguments[++i])
      s += (_.isObject(ii) ? inspect(ii, false, null, true) : ii)+' ';
    console.log(s);
  };
}

var log = makeLogger('helpers');

var byteDimensions = {P: 1024*1024*1024*1024*1024, T: 1024*1024*1024*1024, G: 1024*1024*1024, M: 1024*1024, K: 1024, B: 1};
function byteDimension(nbytes) {
  var dim, base;
  for (dim in byteDimensions) { // assumes largest units first
    base = byteDimensions[dim];
    if (nbytes > base) break;
  }
  return {dim: dim, base: base};
}

function randomChoice(collection) {
  if (_.isArray(collection))
    return collection[_.random(0, collection.length-1)];
  if (_.isPlainObject(collection))
    return randomChoice(_.keys(collection));
  throw new TypeError('expected array or plain object, got '+typeof collection);
}

function applyPatch(obj, patch) {
  patch = new JSONPatch(patch, true); // mutate = true
  patch.apply(obj);
}

function getByPath(obj, path) {
  try {
    return (new JSONPointer(path)).get(obj);
  } catch (e) {
    if (!(e instanceof PatchApplyError)) throw e;
  }
}

var _export = [makeLogger, byteDimension, randomChoice, applyPatch, getByPath];
if (typeof angular == 'object' && angular && typeof angular.module == 'function') {
  var module = angular.module('app.helpers', []);
  _.each(_export, function(func) {
    module.constant(func.name, func);
  });
} else if (typeof exports == 'object' && exports && typeof module == 'object' && module && module.exports == exports) {
  _.each(_export, function(func) {
    exports[func.name] = func;
  });
}

'use strict';

angular.module('app.filters', [])
  // see i18n.js for i18n filter
  .filter('upper', function() {
    return function(s) {
      return angular.uppercase(s);
    };
  })
  .filter('badgeCount', function() {
    return function(str, max) {
      var count = parseInt(str), max = max || 9;
      return count > max ? max + '+' : count;
    };
  })
  .filter('noNullIsland', function() {
    return function(peers) {
      return _.reject(peers, function (peer) {
        return peer.lat === 0.0 && peer.lon === 0.0;
      });
    };
  })
  .filter('prettyUser', function() {
    return function(obj) {
      if (!obj) return obj;
      if (obj.email && obj.name)
        return obj.name + ' <' + obj.email + '>'; // XXX i18n?
      return obj.email;
    };
  })
  .filter('prettyBytes', function($filter) {
    return function(nbytes, dimensionInput, showUnits) {
      if (_.isNaN(nbytes)) return nbytes;
      if (_.isUndefined(dimensionInput)) dimensionInput = nbytes;
      if (_.isUndefined(showUnits)) showUnits = true;
      var dimBase = byteDimension(dimensionInput),
          dim = dimBase.dim,
          base = dimBase.base,
          quotient = $filter('number')(nbytes / base, 1);
      return showUnits ? quotient+' '+dim // XXX i18n?
                       : quotient;
    };
  })
  .filter('prettyBps', function($filter) {
    return function(nbytes, dimensionInput, showUnits) {
      if (_.isNaN(nbytes)) return nbytes;
      if (_.isUndefined(showUnits)) showUnits = true;
      var bytes = $filter('prettyBytes')(nbytes, dimensionInput, showUnits);
      return showUnits ? bytes+'/'+'s' // XXX i18n?
                       : bytes;
    };
  })
  .filter('reportedState', function() {
    return function(model) {
      var state = _.cloneDeep(model);

      // omit these fields
      state = _.omit(state, 'mock', 'countries', 'global');
      delete state.location.lat;
      delete state.location.lon;
      delete state.connectivity.ip;

      // only include these fields from the user's profile
      if (state.profile) {
        state.profile = {email: state.profile.email, name: state.profile.name};
      }

      // replace these array fields with their lengths
      _.each(['/roster', '/settings/proxiedSites', '/friends'], function(path) {
        var len = (getByPath(state, path) || []).length;
        if (len) applyPatch(state, [{op: 'replace', path: path, value: len}]);
      });

      var peers = getByPath(state, '/peers');
      _.each(peers, function (peer) {
        peer.rosterEntry = !!peer.rosterEntry;
        delete peer.peerid;
        delete peer.ip;
        delete peer.lat;
        delete peer.lon;
      });

      return state;
    };
  })
  .filter('version', function() {
    return function(versionObj, tag, git) {
      if (!versionObj) return versionObj;
      var components = [versionObj.major, versionObj.minor, versionObj.patch],
          versionStr = components.join('.');
      if (!tag) return versionStr;
      if (versionObj.tag) versionStr += '-'+versionObj.tag;
      if (!git) return versionStr;
      if (versionObj.git) versionStr += ' ('+versionObj.git.substring(0, 7)+')';
      return versionStr;
    };
  });

'use strict';

angular.module('app.services', [])
  // Messages service will return a map of callbacks that handle websocket
  // messages sent from the flashlight process.
  .service('Messages', function($rootScope, modelSrvc) {

    var model = modelSrvc.model;
    model.instanceStats = {
      allBytes: {
        rate: 0,
      },
    };
    model.peers = [];
    var flashlightPeers = {};
    var queuedFlashlightPeers = {};

    var connectedExpiration = 15000;
    function setConnected(peer) {
      // Consider peer connected if it's been fewer than x seconds since
      // lastConnected
      var lastConnected = Date.parse(peer.lastConnected);
      var delta = new Date().getTime() - Date.parse(peer.lastConnected);
      peer.connected = delta < connectedExpiration;
    }

    // Update last connected for all peers every 10 seconds
    setInterval(function() {
      $rootScope.$apply(function() {
        _.forEach(model.peers, setConnected);
      });
    }, connectedExpiration);

    function applyPeer(peer) {
      // Always set mode to give
      peer.mode = 'give';

      setConnected(peer);
      
      // Update bpsUpDn
      var peerid = peer.peerid;
      var oldPeer = flashlightPeers[peerid];

      var bpsUpDnDelta = peer.bpsUpDn;
      if (oldPeer) {
        // Adjust bpsUpDnDelta by old value
        bpsUpDnDelta -= oldPeer.bpsUpDn;
        // Copy over old peer so that Angular can detect the change
        angular.copy(peer, oldPeer);
      } else {
        // Add peer to model
        flashlightPeers[peerid] = peer;
        model.peers.push(peer);
      }
      model.instanceStats.allBytes.rate += bpsUpDnDelta;
    }
    
    var fnList = {
      'GeoLookup': function(data) {
        console.log('Got GeoLookup information: ', data);
        if (data && data.Location) {
            model.location = {};
            model.location.lon = data.Location.Longitude;
            model.location.lat = data.Location.Latitude;
            model.location.resolved = true;
        }
      },
      'Settings': function(data) {
        console.log('Got Lantern default settings: ', data);
        if (data && data.Version) {
            // configure settings
            // set default client to get-mode
            model.settings = {};
            model.settings.mode = 'get';
            model.settings.version = data.Version + " (" + data.BuildDate + ")";
        }

        if (data.AutoReport) {
            model.settings.autoReport = true;
            if ($rootScope.lanternWelcomeKey) {
                $rootScope.trackPageView();
            }
        }

        if (data.AutoLaunch) {
            model.settings.autoLaunch = true;
        }

        if (data.ProxyAll) {
            model.settings.proxyAll = true;
        }
      },
      'ProxiedSites': function(data) {
        if (!$rootScope.entries) {
          console.log("Initializing proxied sites entries", data.Additions);
          $rootScope.entries = data.Additions;
          $rootScope.originalList = data.Additions;
        } else {
          var entries = $rootScope.entries.slice(0);
          if (data.Additions) {
            entries = _.union(entries, data.Additions);
          }
          if (data.Deletions) {
            entries = _.difference(entries, data.Deletions)
          }
          entries = _.compact(entries);
          entries.sort();

          console.log("About to set entries", entries);
          $rootScope.$apply(function() {
            console.log("Setting entries", entries);
            $rootScope.entries = entries;
            $rootScope.originalList = entries;
          })
        }
      },
      'Stats': function(data) {
        if (data.type != "peer") {
          return;
        }

        if (!model.location) {
          console.log("No location for self yet, queuing peer")
          queuedFlashlightPeers[data.data.peerid] = data.data;
          return;
        }

        $rootScope.$apply(function() {
          if (queuedFlashlightPeers) {
            console.log("Applying queued flashlight peers")
            _.forEach(queuedFlashlightPeers, applyPeer);
            queuedFlashlightPeers = null;
          }

          applyPeer(data.data);
        });
      },
    };

    return fnList;
  })
  .service('modelSrvc', function($rootScope, apiSrvc, $window, MODEL_SYNC_CHANNEL) {
      var model = {},
        syncSubscriptionKey;

    $rootScope.validatedModel = false;

    // XXX use modelValidatorSrvc to validate update before accepting
    function handleSync(msg) {
      var patch = msg.data;
      // backend can send updates before model has been populated
      // https://github.com/getlantern/lantern/issues/587
      if (patch[0].path !== '' && _.isEmpty(model)) {
        //log.debug('ignoring', msg, 'while model has not yet been populated');
        return;
      }

      function updateModel() {
        var shouldUpdateInstanceStats = false;
        if (patch[0].path === '') {
            // XXX jsonpatch can't mutate root object https://github.com/dharmafly/jsonpatch.js/issues/10
            angular.copy(patch[0].value, model);
          } else {
            try {
                applyPatch(model, patch);
                for (var i=0; i<patch.length; i++) {
                    if (patch[i].path == "/instanceStats") {
                        shouldUpdateInstanceStats = true;
                        break;
                      }
                  }
                } catch (e) {
                  if (!(e instanceof PatchApplyError || e instanceof InvalidPatch)) throw e;
                  //log.error('Error applying patch', patch);
                  apiSrvc.exception({exception: e, patch: patch});
                }
            }
        }

        if (!$rootScope.validatedModel) {
            $rootScope.$apply(updateModel());
            $rootScope.validatedModel = true
        } else {
            updateModel();
        }
      }

    syncSubscriptionKey = {chan: MODEL_SYNC_CHANNEL, cb: handleSync};

    return {
      model: model,
      sane: true
    };
  })
  .service('gaMgr', function ($window, DataStream, GOOGLE_ANALYTICS_DISABLE_KEY, GOOGLE_ANALYTICS_WEBPROP_ID) {
    var ga = $window.ga;

    ga('create', GOOGLE_ANALYTICS_WEBPROP_ID, {cookieDomain: 'none'});
    ga('set', {
      anonymizeIp: true,
      forceSSL: true,
      location: 'http://lantern-ui/',
      hostname: 'lantern-ui',
      title: 'lantern-ui'
    });

    function trackPageView(sessionControl) {
      var trackers = ga.getAll();
      for (var i =0; i < trackers.length; i++) {
          var tracker = trackers[i];
          if (tracker.b && tracker.b.data && tracker.b.data.w) {
              var fields = tracker.b.data.w;
              var gaObj = {
                  clientId: '',
                  clientVersion: '',
                  language: '',
                  screenColors: '',
                  screenResolution: '',
                  trackingId: '',
                  viewPortSize: ''
              };
              for (var name in fields) {
                var key = name.split(':')[1];
                if (gaObj.hasOwnProperty(key)) {
                    gaObj[key] = fields[name];
                }
              }
              DataStream.send('Analytics', gaObj);
          }
      }
    }

    return {
      trackPageView: trackPageView
    };
  })
  .service('apiSrvc', function($http, API_URL_PREFIX) {
    return {
      exception: function(data) {
        return $http.post(API_URL_PREFIX+'/exception', data);
      },
      interaction: function(interactionid, data) {
        var url = API_URL_PREFIX+'/interaction/'+interactionid;
        return $http.post(url, data);
      }
    };
  });

'use strict';

app.controller('RootCtrl', ['$rootScope', '$scope', '$compile', '$window', '$http', 
               'localStorageService', 
               function($rootScope, $scope, $compile, $window, $http, localStorageService) {
    $scope.currentModal = 'none';

    $scope.loadScript = function(src) {
        (function() { 
            var script  = document.createElement("script")
            script.type = "text/javascript";
            script.src  = src;
            script.async = true;
            var x = document.getElementsByTagName('script')[0];
            x.parentNode.insertBefore(script, x);
        })();
    };
    $scope.loadShareScripts = function() {
        if (!$window.twttr) {
            // inject twitter share widget script
          $scope.loadScript('//platform.twitter.com/widgets.js');
          // load FB share script
          $scope.loadScript('//connect.facebook.net/en_US/sdk.js#appId=1562164690714282&xfbml=1&version=v2.3');
        }
    };

    $scope.showModal = function(val) {
        if (val == 'welcome') {
            $scope.loadShareScripts();
        }

        $scope.currentModal = val;
    };

    $rootScope.lanternWelcomeKey = localStorageService.get('lanternWelcomeKey');

    $scope.closeModal = function() {

        // if it's our first time opening the UI,
        // show the settings modal first immediately followed by
        // the welcome screen
        if ($scope.currentModal == 'welcome' && !$rootScope.lanternWelcomeKey) {
            $rootScope.lanternWelcomeKey = true;
            localStorageService.set('lanternWelcomeKey', true);
        } else {
            $scope.currentModal = 'none';
        }
    };

    if (!$rootScope.lanternWelcomeKey) {
        $scope.showModal('welcome');
    };


}]);

app.controller('UpdateAvailableCtrl', ['$scope', 'MODAL', function($scope, MODAL) {
  $scope.show = false;
  $scope.$watch('model.modal', function (modal) {
    $scope.show = modal === MODAL.updateAvailable;
  });
}]);

app.controller('ContactCtrl', ['$scope', 'MODAL', function($scope, MODAL) {
  $scope.show = false;
  $scope.notify = true; // so the view's interactionWithNotify calls include $scope.message and $scope.diagnosticInfo
  $scope.$watch('model.modal', function (modal) {
    $scope.show = modal === MODAL.contact;
    $scope.resetContactForm($scope);
  });
}]);

app.controller('ConfirmResetCtrl', ['$scope', 'MODAL', function($scope, MODAL) {
  $scope.show = false;
  $scope.$watch('model.modal', function (modal) {
    $scope.show = modal === MODAL.confirmReset;
  });
}]);

app.controller('SettingsCtrl', ['$scope', 'MODAL', 'DataStream', 'gaMgr', function($scope, MODAL, DataStream, gaMgr) {
  $scope.show = false;

  $scope.$watch('model.modal', function (modal) {
    $scope.show = modal === MODAL.settings;
  });

  $scope.changeReporting = function(autoreport) {
      var obj = {
        autoReport: autoreport
      };
      DataStream.send('Settings', obj);
  };

  $scope.changeAutoLaunch = function(autoLaunch) {
      var obj = {
        autoLaunch: autoLaunch
      };
      DataStream.send('Settings', obj);
  }

  $scope.changeProxyAll = function(proxyAll) {
      var obj = {
        proxyAll: proxyAll
      };
      DataStream.send('Settings', obj);
  }

  $scope.$watch('model.settings.systemProxy', function (systemProxy) {
    $scope.systemProxy = systemProxy;
  });

  $scope.$watch('model.settings.proxyAllSites', function (proxyAllSites) {
    $scope.proxyAllSites = proxyAllSites;
  });
}]);

app.controller('ProxiedSitesCtrl', ['$rootScope', '$scope', '$filter', 'SETTING', 'INTERACTION', 'INPUT_PAT', 'MODAL', 'ProxiedSites', function($rootScope, $scope, $filter, SETTING, INTERACTION, INPUT_PAT, MODAL, ProxiedSites) {
      var fltr = $filter('filter'),
      DOMAIN = INPUT_PAT.DOMAIN,
      IPV4 = INPUT_PAT.IPV4,
      nproxiedSitesMax = 10000,
      proxiedSitesDirty = [];

  $scope.proxiedSites = ProxiedSites.entries;

  $scope.arrLowerCase = function(A) {
      if (A) {
        return A.join('|').toLowerCase().split('|');
      } else {
        return [];
      }
  }

  $scope.setFormScope = function(scope) {
      $scope.formScope = scope;
  };

  $scope.resetProxiedSites = function(reset) {
    if (reset) {
        $rootScope.entries = $rootScope.global;
        $scope.input = $scope.proxiedSites;
        makeValid();
    } else {
        $rootScope.entries = $rootScope.originalList;
        $scope.closeModal();
    }
  };

  $scope.show = false;

  $scope.$watch('searchText', function (searchText) {
    if (!searchText ) {
        $rootScope.entries = $rootScope.originalList;
    } else {
        $rootScope.entries = (searchText ? fltr(proxiedSitesDirty, searchText) : proxiedSitesDirty);
    }
  });

  function makeValid() {
    $scope.errorLabelKey = '';
    $scope.errorCause = '';
    if ($scope.proxiedSitesForm && $scope.proxiedSitesForm.input) {
      $scope.proxiedSitesForm.input.$setValidity('generic', true);
    }
  }

  /*$scope.$watch('proxiedSites', function(proxiedSites_) {
    if (proxiedSites) {
      proxiedSites = normalizedLines(proxiedSites_);
      $scope.input = proxiedSites.join('\n');
      makeValid();
      proxiedSitesDirty = _.cloneDeep(proxiedSites);
    }
  }, true);*/

  function normalizedLine (domainOrIP) {
    return angular.lowercase(domainOrIP.trim());
  }

  function normalizedLines (lines) {
    return _.map(lines, normalizedLine);
  }

  $scope.validate = function (value) {
    if (!value || !value.length) {
      $scope.errorLabelKey = 'ERROR_ONE_REQUIRED';
      $scope.errorCause = '';
      return false;
    }
    if (angular.isString(value)) value = value.split('\n');
    proxiedSitesDirty = [];
    var uniq = {};
    $scope.errorLabelKey = '';
    $scope.errorCause = '';
    for (var i=0, line=value[i], l=value.length, normline;
         i<l && !$scope.errorLabelKey;
         line=value[++i]) {
      normline = normalizedLine(line);
      if (!normline) continue;
      if (!(DOMAIN.test(normline) ||
            IPV4.test(normline))) {
        $scope.errorLabelKey = 'ERROR_INVALID_LINE';
        $scope.errorCause = line;
      } else if (!(normline in uniq)) {
        proxiedSitesDirty.push(normline);
        uniq[normline] = true;
      }
    }
    if (proxiedSitesDirty.length > nproxiedSitesMax) {
      $scope.errorLabelKey = 'ERROR_MAX_PROXIED_SITES_EXCEEDED';
      $scope.errorCause = '';
    }
    $scope.hasUpdate = !_.isEqual(proxiedSites, proxiedSitesDirty);
    return !$scope.errorLabelKey;
  };

  $scope.setDiff  = function(A, B) {
      return A.filter(function (a) {
          return B.indexOf(a) == -1;
      });
  };

  $scope.handleContinue = function () {
    $rootScope.updates = {};

    if ($scope.proxiedSitesForm.$invalid) {
      return $scope.interaction(INTERACTION.continue);
    }

    $scope.entries = $scope.arrLowerCase(proxiedSitesDirty);
    $rootScope.updates.Additions = $scope.setDiff($scope.entries,
                                       $scope.originalList);
    $rootScope.updates.Deletions = $scope.setDiff($scope.originalList, $scope.entries);

    ProxiedSites.update();

    $scope.closeModal();
  };
}]);

'use strict';

var directives = angular.module('app.directives', [])
  .directive('compileUnsafe', function ($compile) {
    return function (scope, element, attr) {
      scope.$watch(attr.compileUnsafe, function (val, oldVal) {
        if (!val || (val === oldVal && element[0].innerHTML)) return;
        element.html(val);
        $compile(element)(scope);
      });
    };
  })
  .directive('focusOn', function ($parse) {
    return function(scope, element, attr) {
      var val = $parse(attr['focusOn']);
      scope.$watch(val, function (val) {
        if (val) {
          element.focus();
        }
      });
    }
  });

// XXX https://github.com/angular/angular.js/issues/1050#issuecomment-9650293
angular.forEach(['x', 'y', 'cx', 'cy', 'd', 'fill', 'r'], function(name) {
  var ngName = 'ng' + name[0].toUpperCase() + name.slice(1);
  directives.directive(ngName, function() {
    return function(scope, element, attrs) {
      attrs.$observe(ngName, function(value) {
        attrs.$set(name, value); 
      })
    };
  });
});

'use strict';

var PI = Math.PI,
    TWO_PI = 2 * PI,
    abs = Math.abs,
    min = Math.min,
    max = Math.max,
    round = Math.round;

angular.module('app.vis', ['ngSanitize'])
  .directive('resizable', function ($window) {
    return function (scope, element) {
      function size() {
        var w = element[0].offsetWidth, h = element[0].offsetHeight;
        scope.projection.scale(max(w, h) / TWO_PI);
        scope.projection.translate([w >> 1, round(0.56*h)]);
        scope.$broadcast('mapResized', w, h);
      }

      size();

      angular.element($window).bind('resize', _.throttle(size, 500, {leading: false}));
    };
  })
  .directive('globe', function () {
    return function (scope, element) {
      var d = scope.path({type: 'Sphere'});
      element.attr('d', d);
    };
  })
  .directive('countries', function ($compile, $timeout, $window) {
    function ttTmpl(alpha2) {
      return '<div class="vis" style="min-width:150px; cursor:pointer;">'+
        '<div class="header">{{ "'+alpha2+'" | translate }}</div>'+
        '<div class="give-colored">{{ (model.countries.'+ alpha2+'.stats.gauges.userOnlineGiving == 1 ? "NUSERS_ONLINE_1" : "NUSERS_ONLINE_OTHER") | translate: \'{ value: model.countries.'+alpha2+'.stats.gauges.userOnlineGiving || 0 }\' }} {{ "GIVING_ACCESS" | translate }}</div>'+
        '<div class="get-colored">{{ (model.countries.'+alpha2+'.stats.gauges.userOnlineGetting == 1 ? "NUSERS_ONLINE_1" : "NUSERS_ONLINE_OTHER") | translate: \'{value: model.countries.'+alpha2+'.stats.gauges.userOnlineGetting || 0 }\' }} {{ "GETTING_ACCESS" | translate }}</div>'+
        '<div class="nusers {{ (!model.countries.'+alpha2+'.stats.gauges.userOnlineEver && !model.countries.'+alpha2+'.stats.counters.userOnlineEverOld) && \'gray\' || \'\' }}">'+
          '{{ (model.countries.'+alpha2+'.stats.gauges.userOnlineEver + model.countries.'+alpha2+'.stats.gauges.userOnlineEverOld) == 1 ? "NUSERS_EVER_1" : "NUSERS_EVER_OTHER" | translate: \'{ value: (model.countries.'+alpha2+'.stats.gauges.userOnlineEver + model.countries.'+alpha2+'.stats.gauges.userOnlineEverOld) }\' }}'+
        '</div>'+
        '<div class="stats">'+
          '<div class="bps{{ model.countries.'+alpha2+'.bps || 0 }}">'+
            '{{ model.countries.'+alpha2+'.bps || 0 | prettyBps }} {{ "TRANSFERRING_NOW" | translate }}'+
          '</div>'+
          '<div class="bytes{{ model.countries.'+alpha2+'.bytesEver || 0 }}">'+
            '{{model.countries.'+alpha2+'.stats.counters.bytesGiven | prettyBytes}} {{"GIVEN" | translate}}, ' +
            '{{model.countries.'+alpha2+'.stats.counters.bytesGotten | prettyBytes}} {{"GOTTEN" | translate}}' +
          '</div>'+
        '</div>'+
      '</div>';
    }

    return function (scope, element) {
      var maxNpeersOnline = 0,
          strokeOpacityScale = d3.scale.linear()
            .clamp(true).domain([0, 0]).range([0, 1]);

      // detect reset
      scope.$watch('model.setupComplete', function (newVal, oldVal) {
        if (oldVal && !newVal) {
          maxNpeersOnline = 0;
          strokeOpacityScale.domain([0, 0]);
        }
      }, true);

      var unwatch = scope.$watch('model.countries', function (countries) {
        if (!countries) return;
        d3.select(element[0]).selectAll('path').each(function (d) {
          var censors = !!getByPath(countries, '/'+d.alpha2+'/censors'); 
          if (censors) {
            d3.select(this).classed('censors', censors);
          }
        });
        unwatch();
      }, true);
      
      // Format connectivity ip for display
      scope.$watch('model.connectivity', function(connectivity) {
        if (connectivity) {
          if (model.dev) {
            connectivity.formattedIp = " (" + connectivity.ip + ")"; 
          }
        }
      });

      // Set up the world map once and only once
      d3.json('data/world.topojson', function (error, world) {
        if (error) throw error;
        //XXX need to do something like this to use latest topojson:
        //var f = topojson.feature(world, world.objects.countries).features;
        var countries = topojson.object(world, world.objects.countries).geometries;
        var country = d3.select(element[0]).selectAll('path').data(countries);
        country.enter()
          .append("g").append("path")
          .attr("title", function(d,i) { return d.name; })
          .each(function (d) {
            var el = d3.select(this);
            el.attr('d', scope.path).attr('stroke-opacity', 0);
            el.attr('class', 'COUNTRY_KNOWN');
            if (d.alpha2) {
              //var $content = ttTmpl(d.alpha2);

              el.attr('class', d.alpha2 + " COUNTRY_KNOWN");
                // .attr('tooltip-placement', 'mouse')
                //.attr('tooltip-html-unsafe', $content);
                // $compile(this)(scope);
            } else {
              el.attr('class', 'COUNTRY_UNKNOWN');
            }
          });
      });
      
      /*
       * Every time that our list of countries changes, do the following:
       * 
       * - Iterate over all countries to fine the maximum number of peers online
       *   (used for scaling opacity of countries)
       * - Update the opacity for every country based on our new scale
       * - For all countries whose number of online peers has changed, make the
       *   country flash on screen for half a second (this is done in bulk to
       *   all countries at once)
       */
      scope.$watch('model.countries', function (newCountries, oldCountries) {
        var changedCountriesSelector = "";
        var firstChangedCountry = true;
        var npeersOnlineByCountry = {};
        var countryCode, newCountry, oldCountry;
        var npeersOnline, oldNpeersOnline;
        var updated;
        var changedCountries;
        
        for (countryCode in newCountries) {
          newCountry = newCountries[countryCode];
          oldCountry = oldCountries ? oldCountries[countryCode] : null;
          npeersOnline = getByPath(newCountry, '/npeers/online/giveGet') || 0;
          oldNpeersOnline = oldCountry ? getByPath(oldCountry, '/npeers/online/giveGet') || 0 : 0;
          
          npeersOnlineByCountry[countryCode] = npeersOnline;
          
          // Remember the maxNpeersOnline
          if (npeersOnline > maxNpeersOnline) {
            maxNpeersOnline = npeersOnline;
          }
          
          // Country changed number of peers online, flag it
          if (npeersOnline !== oldNpeersOnline) {
            if (!firstChangedCountry) {
              changedCountriesSelector += ", ";
            }
            changedCountriesSelector += "." + countryCode;
            firstChangedCountry = false;
          }
        }
        
        // Update opacity for all known countries
        strokeOpacityScale.domain([0, maxNpeersOnline]);
        d3.select(element[0]).selectAll("path.COUNTRY_KNOWN").attr('stroke-opacity', function(d) {
          return strokeOpacityScale(npeersOnlineByCountry[d.alpha2] || 0);
        });
        
        // Flash update for changed countries
        if (changedCountriesSelector.length > 0) {
          changedCountries = d3.select(element[0]).selectAll(changedCountriesSelector); 
          changedCountries.classed("updating", true);
          $timeout(function () {
            changedCountries.classed('updating', false);
          }, 500);
        }
      }, true);
    };
  })
  .directive('peers', function ($compile, $filter) {
    var noNullIsland = $filter('noNullIsland');
    return function (scope, element) {
      // Template for our peer tooltips
      var peerTooltipTemplate = "<div class=vis> \
          <div class='{{peer.mode}} {{peer.type}}'> \
          <img class=picture src='{{peer.rosterEntry.picture || DEFAULT_AVATAR_URL}}'> \
          <div class=headers> \
            <div class=header>{{peer.rosterEntry.name}}</div> \
            <div class=email>{{peer.rosterEntry.email}}</div> \
            <div class='peerid ip'>{{peer.peerid}}{{peer.formattedIp}}</div> \
            <div class=type>{{peer.type && peer.mode && (((peer.type|upper)+(peer.mode|upper))|translate) || ''}}</div> \
          </div> \
          <div class=stats> \
            <div class=bps{{peer.bpsUpDn}}> \
              {{peer.bpsUp | prettyBps}} {{'UP' | translate}}, \
              {{peer.bpsDn | prettyBps}} {{'DN' | translate}} \
            </div> \
            <div class=bytes{{peer.bytesUpDn}}> \
              {{peer.bytesUp | prettyBytes}} {{'SENT' | translate}}, \
              {{peer.bytesDn | prettyBytes}} {{'RECEIVED' | translate}} \
            </div> \
            <div class=lastConnected> \
              {{!peer.connected && peer.lastConnected && 'LAST_CONNECTED' || '' | translate }} \
              <time>{{!peer.connected && (peer.lastConnected | date:'short') || ''}}</time> \
            </div> \
          </div> \
        </div> \
      </div>";
      
      // Scaling function for our connection opacity
      var connectionOpacityScale = d3.scale.linear()
        .clamp(true).domain([0, 0]).range([0, .9]);
      
      // Functions for calculating arc dimensions
      function getTotalLength(d) { return this.getTotalLength() || 0.0000001; }
      function getDashArray(d) { var l = this.getTotalLength(); return l+' '+l; }
      
      // Peers are uniquely identified by their peerid.
      function peerIdentifier(peer) {
        return peer.peerid;
      }
      
      /**
       * Return the CSS escaped version of the peer identifier
       */
      function escapedPeerIdentifier(peer) {
        return cssesc(peerIdentifier(peer), {isIdentifier: true});
      }
      
      var peersContainer = d3.select(element[0]);
      
      /*
       * Every time that our list of peers changes, we do the following:
       * 
       * For new peers only:
       * 
       * - Create an SVG group to contain everything related to that peer
       * - Create another SVG group to contain their dot/tooltip
       * - Add dots to show them on the map
       * - Add a hover target around the dot that activates a tooltip
       * - Bind those tooltips to the peer's data using Angular
       * - Add an arc connecting the user's dot to the peer
       * 
       * For all peers:
       * 
       * - Adjust the position of the peer dots
       * - Adjust the style of the peer dots based on whether or not the peer
       *   is currently connected
       * 
       * For all connecting arcs:
       * 
       * - Adjust the path of the arc based on the peer's current position
       * - If the peer has become connected, animate it to become visible
       * - If the peer has become disconnected, animate it to become hidden
       * - note: the animation is done in bulk for all connected/disconnected
       *   arcs
       * 
       * For disappeared peers:
       * 
       * - Remove their group, which removes everything associated with that
       *   peer
       * 
       */
      function renderPeers(peers, oldPeers) {
        if (!peers) return;

        // disregard peers on null island
        peers = noNullIsland(peers);
        oldPeers = noNullIsland(oldPeers);
      
        // Figure out our maxBps
        var maxBpsUpDn = 0;
        peers.forEach(function(peer) {
          if (maxBpsUpDn < peer.bpsUpDn)
            maxBpsUpDn = peer.bpsUpDn;
        });
        if (maxBpsUpDn !== connectionOpacityScale.domain()[1]) {
          connectionOpacityScale.domain([0, maxBpsUpDn]);
        }
        
        // Set up our d3 selections
        var allPeers = peersContainer.selectAll("g.peerGroup").data(peers, peerIdentifier);
        var newPeers = allPeers.enter().append("g").classed("peerGroup", true);
        var departedPeers = allPeers.exit();
        
        // Add groups for new peers, including tooltips
        var peerItems = newPeers.append("g")
          .attr("id", peerIdentifier)
          .classed("peer", true)
          .attr("tooltip-placement", "bottom")
          .attr("tooltip-html-unsafe", peerTooltipTemplate)
          .each(function(peer) {
            // Compile the tooltip target dom element to enable the tooltip-html-unsafe directive
            var childScope = scope.$new();
            childScope.peer = peer;
            // Format the ip for display
            if (model.dev && peer.ip) {
              peer.formattedIp = " (" + peer.ip + ")";
            }
            $compile(this)(childScope);
          });
        
        // Create points and hover areas for each peer
        peerItems.append("path").classed("peer", true);
        peerItems.append("path").classed("peer-hover-area", true);
        
        // Configure points and hover areas on each update
        allPeers.select("g.peer path.peer").attr("d", function(peer) {
            return scope.path({type: 'Point', coordinates: [peer.lon, peer.lat]})
        })
        .attr("filter", "url(#defaultBlur)")
        .attr("class", function(peer) {
          var result = "peer " + peer.mode + " " + peer.type;
          if (peer.connected) {
            result += " connected";
          }
          return result;
        });

        // Configure hover areas for all peers
        allPeers.select("g.peer path.peer-hover-area")
        .attr("d", function(peer) {
          return scope.path({type: 'Point', coordinates: [peer.lon, peer.lat]}, 6);
        });
        
        // Add arcs for new peers
        newPeers.append("path")
          .classed("connection", true)
          .attr("id", function(peer) { return "connection_to_" + peerIdentifier(peer); });
        
          // Set paths for arcs for all peers
          allPeers.select("path.connection")
          .attr("d", scope.pathConnection)
          .attr("stroke-opacity", function(peer) {
              return connectionOpacityScale(peer.bpsUpDn || 0);
          });

        // Animate connected/disconnected peers
        var newlyConnectedPeersSelector = "";
        var firstNewlyConnectedPeer = true;
        var newlyDisconnectedPeersSelector = "";
        var firstNewlyDisconnectedPeer = true;
        var oldPeersById = {};
        
        if (oldPeers) {
          oldPeers.forEach(function(oldPeer) {
            oldPeersById[peerIdentifier(oldPeer)] = oldPeer;
          });
        }
        
        // Find out which peers have had status changes
        peers.forEach(function(peer) {
          var peerId = peerIdentifier(peer);
          var escapedPeerId = escapedPeerIdentifier(peer);
          var oldPeer = oldPeersById[peerId];
          if (peer.connected) {
            if (!oldPeer || !oldPeer.connected) {
              if (!firstNewlyConnectedPeer) {
                newlyConnectedPeersSelector += ", ";
              }
              newlyConnectedPeersSelector += "#connection_to_" + escapedPeerId;
              firstNewlyConnectedPeer = false;
            }
          } else {
            if (!oldPeer || oldPeer.connected) {
              if (!firstNewlyDisconnectedPeer) {
                newlyDisconnectedPeersSelector += ", ";
              }
              newlyDisconnectedPeersSelector += "#connection_to_" + escapedPeerId;
              firstNewlyDisconnectedPeer = false;
            }
          }
        });
        
        if (newlyConnectedPeersSelector) {
          peersContainer.selectAll(newlyConnectedPeersSelector)
            .transition().duration(500)
              .each('start', function() {
                d3.select(this)
                  .attr('stroke-dashoffset', getTotalLength)
                  .attr('stroke-dasharray', getDashArray)
                  .classed('active', true);
              }).attr('stroke-dashoffset', 0);
        }
        
        if (newlyDisconnectedPeersSelector) {
          peersContainer.selectAll(newlyDisconnectedPeersSelector)
            .transition().duration(500)
            .each('start', function() {
              d3.select(this)
                .attr('stroke-dashoffset', 0)
                .attr('stroke-dasharray', getDashArray)
                .classed('active', false);
            }).attr('stroke-dashoffset', getTotalLength);
        }
        
        // Remove departed peers
        departedPeers.remove();

        scope.redraw(scope.zoom.translate(), scope.zoom.scale());
      }
      
      // Handle model changes
      scope.$watch('model.peers', renderPeers, true);
      
      // Handle resize
      scope.$on("mapResized", function() {

        d3.selectAll('#countries path').attr('d', scope.path);

        // Whenever the map resizes, we need to re-render the peers and arcs
        renderPeers(scope.model.peers, scope.model.peers);

        // The above render call left the arcs alone because there were no
        // changes.  We now need to do some additional maintenance on the arcs.
        
        // First clear the stroke-dashoffset and stroke-dasharray for all connections
        peersContainer.selectAll("path.connection")
          .attr("stroke-dashoffset", null)
          .attr("stroke-dasharray", null);
        
        // Then for active connections, update their values
        peersContainer.selectAll("path.connection.active")
          .attr("stroke-dashoffset", 0)
          .attr("stroke-dasharray", getDashArray);

        scope.redraw(scope.zoom.translate(), scope.zoom.scale());
      });
    };
  });

app.controller('VisCtrl', ['$scope', '$rootScope', '$compile', '$window', '$timeout', '$filter',  'modelSrvc', 'apiSrvc', function($scope, $rootScope, $compile, $window, $timeout, $filter, modelSrvc, apiSrvc) {

  var model = modelSrvc.model,
      isSafari = Object.prototype.toString.call(window.HTMLElement).indexOf('Constructor') > 0,
      width = document.getElementById('vis').offsetWidth,
      height = document.getElementById('vis').offsetHeight,
      projection = d3.geo.mercator(),
      path = d3.geo.path().projection(projection),
      DEFAULT_POINT_RADIUS = 3;

  $scope.projection = projection;

  $scope.once = false;

  /* the self dot isn't dynamically appended to the SVG
   * and we need a separate method to scale it when we zoom in/out
   */
  $scope.scaleSelf = function(factor) {
      var self = document.getElementById("self");
      var lat = self.getAttribute("lat");
      var lon = self.getAttribute("lon");
      if (self.getAttribute('d') != null &&
          lat != '' && lon != '') {
        var d = {type: 'Point', coordinates: [lon, 
                lat]};
        self.setAttribute('d', path(d));
      }
  };

  function scaleMapElements(scale) {
      var scaleFactor = (scale > 2) ? (5/scale) : DEFAULT_POINT_RADIUS;
      // stroke width is based off minimum threshold or scaled amount
      // according to user zoom-level
      var strokeWidth = Math.min(0.5, 1/scale);
      path.pointRadius(scaleFactor);
      $scope.scaleSelf(scaleFactor);
      d3.selectAll("#countries path").attr("stroke-width", 
        strokeWidth);
      d3.selectAll("path.connection").attr("stroke-width",
        strokeWidth);
      d3.select("#zoomCenter").classed('zoomedIn', scale != 1);

       /* scale peer radius as we zoom in */
      d3.selectAll("g.peer path.peer").attr("d", function(peer) {
          var d = {type: 'Point', coordinates: [peer.lon, peer.lat]};
          return path(d);
      });

      /* adjust gaussian blur by zoom level */
      if (scale > 2) {
          $scope.filterBlur.attr("stdDeviation", Math.min(1.0, 1/scale));
      } else {
          $scope.filterBlur.attr("stdDeviation", 0.8);
      }
      
  }
  
  // Constrain translate to prevent panning off map
  function constrainTranslate(translate, scale) {
    var vz = document.getElementById('vis'); 
    var w = vz.offsetWidth;
    var h = vz.offsetHeight;
    var topLeft = [0, 0];
    var bottomRight = [w * (scale - 1), h * (scale - 1)];  
    bottomRight[0] = -1 * bottomRight[0];
    bottomRight[1] = -1 * bottomRight[1];
    return [ Math.max(Math.min(translate[0], topLeft[0]), bottomRight[0]),
             Math.max(Math.min(translate[1], topLeft[1]), bottomRight[1]) ];
  }

  $scope.redraw = function(translate, scale) {

      translate = !translate ? d3.event.translate : translate;
      scale = !scale ? d3.event.scale : scale;

      translate = constrainTranslate(translate, scale);
      
      // Update the translate on the D3 zoom behavior to our constrained
      // value to keep them in sync.
      $scope.zoom.translate(translate);
      
      /* reset translation matrix */
      $scope.transMatrix = [scale, 0, 0, scale, 
        translate[0], translate[1]];

      d3.select("#zoomGroup").attr("transform", 
        "translate(" + translate.join(",") + ")scale(" + scale + ")");
    
      scaleMapElements(scale);

  };

  $scope.zoom = d3.behavior.zoom().scaleExtent([1,10]).on("zoom", 
                $scope.redraw);

   /* apply zoom behavior to container if we're running in webview since
    * it doesn't detect panning/zooming otherwise */
   d3.select(isSafari ? '#vis' : 'svg').call($scope.zoom);
   $scope.svg = d3.select('svg');
   $scope.filterBlur = $scope.svg.append("filter").attr("id", "defaultBlur").append("feGaussianBlur").attr("stdDeviation", "1");
  
  /* translation matrix on container zoom group element 
  *  used for combining scaling and translation transformations
  *  and for programmatically setting scale and zoom settings
  * */
  $scope.transMatrix = [1,0,0,1,0,0];

  $scope.centerZoom = function() {
    d3.select("#zoomGroup").attr("transform", "translate(0,0),scale(1)");
    $scope.zoom.translate([0,0]);
    $scope.zoom.scale([1]);
    $scope.redraw([0,0], 1);
  };

  $scope.adjustZoom = function(scale) {
      /* limit zoom range */
      if ((scale == 0.8 && $scope.zoom.scale() <= 1) ||
          (scale == 1.25 && $scope.zoom.scale() > 9)) {
        return;
      }

      var map = document.getElementById("map");
      var rect = map.getBoundingClientRect();
      var width = rect.width;
      var height = rect.height;

      /* multiply values in our translation matrix
       * by the scaling factor
       */
      for (var i=0; i< $scope.transMatrix.length; i++)
      {
          $scope.transMatrix[i] *= scale;
      }

      /* this preserves the position of the center
       * even after we've applied the scale factor */
      var translate = [$scope.transMatrix[4] + (1-scale)*width/2,
                       $scope.transMatrix[5] + (1-scale)*height/2];
      translate = constrainTranslate(translate, $scope.transMatrix[0]);
      $scope.transMatrix[4] = translate[0];
      $scope.transMatrix[5] = translate[1];
      
      var newMatrix = "matrix(" +  $scope.transMatrix.join(' ') + ")";
      d3.select("#zoomGroup").attr("transform", newMatrix);

      scaleMapElements($scope.transMatrix[0]);

      /* programmatically update our zoom translation vector and scale */
      $scope.zoom.translate([$scope.transMatrix[4], $scope.transMatrix[5]]);
      $scope.zoom.scale($scope.transMatrix[0]);
  };

  $scope.path = function (d, pointRadius) {
      path.pointRadius(pointRadius || DEFAULT_POINT_RADIUS);
      return path(d) || 'M0 0';
  };

  $scope.pathConnection = function (peer) {
    var MINIMUM_PEER_DISTANCE_FOR_NORMAL_ARCS = 30;
    
    var pSelf = projection([model.location.lon, model.location.lat]),
        pPeer = projection([peer.lon, peer.lat]),
        xS = pSelf[0], yS = pSelf[1], xP = pPeer[0], yP = pPeer[1];
    
    var distanceBetweenPeers = Math.sqrt(Math.pow(xS - xP, 2) + Math.pow(yS - yP, 2));
    var xL, xR, yL, yR;
    
    if (distanceBetweenPeers < MINIMUM_PEER_DISTANCE_FOR_NORMAL_ARCS) {
      // Peer and self are very close, draw a loopy arc
      // Make sure that the arc's line doesn't cross itself by ordering the
      // peers from left to right
      if (xS < xP) {
        xL = xS;
        yL = yS;
        xR = xP;
        yR = yP;
      } else {
        xL = xP;
        yL = yP;
        xR = xS;
        yR = yS;
      }
      var xC1 = Math.min(xL, xR) - MINIMUM_PEER_DISTANCE_FOR_NORMAL_ARCS * 2 / 3;
      var xC2 = Math.max(xL, xR) + MINIMUM_PEER_DISTANCE_FOR_NORMAL_ARCS * 2 / 3;
      var yC = Math.max(yL, yR) + MINIMUM_PEER_DISTANCE_FOR_NORMAL_ARCS;
      return 'M'+xL+','+yL+' C '+xC1+','+yC+' '+xC2+','+yC+' '+xR+','+yR;
    } else {
      // Peer and self are at different positions, draw arc between them
      var controlPoint = [abs(xS+xP)/2, min(yS, yP) - abs(xP-xS)*0.3],
          xC = controlPoint[0], yC = controlPoint[1];
      return $scope.inGiveMode ?
          'M'+xP+','+yP+' Q '+xC+','+yC+' '+xS+','+yS :
          'M'+xS+','+yS+' Q '+xC+','+yC+' '+xP+','+yP;
    }
  };
}]);
