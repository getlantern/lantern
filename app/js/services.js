'use strict';

angular.module('app.services', [])
  .service('modelSrvc', function($rootScope, apiSrvc, $window, MODEL_SYNC_CHANNEL,  flashlightStats) {
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
            flashlightStats.updateModel(model, shouldUpdateInstanceStats);
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
  .service('gaMgr', function ($window, GOOGLE_ANALYTICS_DISABLE_KEY, GOOGLE_ANALYTICS_WEBPROP_ID, modelSrvc) {
      var model = modelSrvc.model,
        ga = $window.ga;

    function stopTracking() {
      //log.debug('disabling analytics');
      //trackPageView('end'); // force the current session to end with this hit
      $window[GOOGLE_ANALYTICS_DISABLE_KEY] = true;
    }

    function startTracking() {
      //log.debug('enabling analytics');
      $window[GOOGLE_ANALYTICS_DISABLE_KEY] = false;
      trackPageView('start');
    }

    // start out with google analytics disabled
    // https://developers.google.com/analytics/devguides/collection/analyticsjs/advanced#optout
    stopTracking();

    // but get a tracker set up and ready for use if analytics become enabled
    // https://developers.google.com/analytics/devguides/collection/analyticsjs/field-reference
    ga('create', GOOGLE_ANALYTICS_WEBPROP_ID, {cookieDomain: 'none'});
    ga('set', {
      anonymizeIp: true,
      forceSSL: true,
      location: 'http://lantern-ui/',
      hostname: 'lantern-ui',
      title: 'lantern-ui'
    });

    function trackPageView(sessionControl) {
      var page = model.modal || '/';
      ga('set', 'page', page);
      ga('send', 'pageview', sessionControl ? {sessionControl: sessionControl} : undefined);
      //log.debug(sessionControl === 'end' ? 'sent analytics session end' : 'tracked pageview', 'page =', page);
    }

    return {
      stopTracking: stopTracking,
      startTracking: startTracking,
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
  })
  .service('flashlightStats', function ($window) {
    // This service grabs stats from flashlight and adds them to the standard
    // model.
    var flashlightPeers = {};

    // connect() starts listening for peer updates
    function connect() {
      var source = new EventSource('http://127.0.0.1:15670/');
      source.addEventListener('message', function(e) {
        var data = JSON.parse(e.data);
        if (data.type == "peer") {
          var peer = data.data;
          peer.mode = 'get';
          flashlightPeers[peer.peerid] = peer;
        }
      }, false);
  
      source.addEventListener('open', function(e) {
        //$log.debug("flashlight connection opened");
      }, false);
  
      source.addEventListener('error', function(e) {
        if (e.readyState == EventSource.CLOSED) {
          //$log.debug("flashlight connection closed");
        }
      }, false);
    }
    
    // updateModel updates a model that doesn't include flashlight peers with
    // information about the flashlight peers, including updating aggregated
    // figure slike total bps.
    function updateModel(model, shouldUpdateInstanceStats) {
      for (var peerid in flashlightPeers) {
        var peer = flashlightPeers[peerid];
        
        // Consider peer connected if it's been less than x seconds since
        // lastConnected
        var lastConnected = Date.parse(peer.lastConnected);
        var delta = new Date().getTime() - Date.parse(peer.lastConnected);
        peer.connected = delta < 30000;
        
        // Add peer to model
        model.peers.push(peer);
        
        if (shouldUpdateInstanceStats) {
          // Update total bytes up/dn
          model.instanceStats.allBytes.rate += peer.bpsUpDn;
        }
      }
    }
    
    return {
      connect: connect,
      updateModel: updateModel,
    };
  });
