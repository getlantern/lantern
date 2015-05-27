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
