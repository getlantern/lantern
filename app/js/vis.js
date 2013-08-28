'use strict';

var PI = Math.PI,
    TWO_PI = 2 * PI,
    abs = Math.abs,
    min = Math.min,
    max = Math.max,
    round = Math.round;

angular.module('app.vis', [])
  .directive('resizable', function ($window) {
    return function (scope, element) {
      function size() {
        var w = element.width(), h = element.height();
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
  .directive('self', function () {
    return function (scope, element) {
      scope.$on('mapResized', function () {
        try {
          scope.$digest();
        } catch (e) {
          if (e.message !== '$digest already in progress') {
            throw e;
          }
        }
      });
    };
  })
  .directive('countries', function ($compile, $timeout) {

    function ttTmpl(alpha2) {
      return '<div class="vis">'+
        '<div class="header">{{ "'+alpha2+'" | i18n }}</div>'+
        '<div class="give-colored">{{ "NPEERS_ONLINE_GIVE" | i18n:model.countries.'+alpha2+'.npeers.online.give }}</div>'+
        '<div class="get-colored">{{ "NPEERS_ONLINE_GET" | i18n:model.countries.'+alpha2+'.npeers.online.get }}</div>'+
        '<div class="nusers {{ (!model.countries.'+alpha2+'.nusers.ever) && \'gray\' || \'\' }}">'+
          '{{ "NUSERS_EVER" | i18n:model.countries.'+alpha2+'.nusers.ever }}'+
        '</div>'+
        '<div class="stats">'+
          '<div class="bps{{ model.countries.'+alpha2+'.bps || 0 }}">'+
            '{{ model.countries.'+alpha2+'.bps || 0 | prettyBps }} {{ "TRANSFERRING_NOW" | i18n }}'+
          '</div>'+
          '<div class="bytes{{ model.countries.'+alpha2+'.bytesEver || 0 }}">'+
            '{{ model.countries.'+alpha2+'.bytesEver || 0 | prettyBytes }} {{ "TRANSFERRED_EVER" | i18n }}'+
          '</div>'+
        '</div>'+
      '</div>';
    }

    return function (scope, element) {
      var maxNpeersOnline = 0,
          strokeOpacityScale = d3.scale.linear()
            .clamp(true).domain([0, 0]).range([0, 1]);

      // Handle resize
      scope.$on('mapResized', function () {
        d3.selectAll('#countries path').attr('d', scope.path);
      });

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

      // Set up the world map once and only once
      d3.json('data/world.topojson', function (error, world) {
        if (error) throw error;
        //XXX need to do something like this to use latest topojson:
        //var f = topojson.feature(world, world.objects.countries).features;
        var f = topojson.object(world, world.objects.countries).geometries;
        d3.select(element[0]).selectAll('path').data(f).enter().append("g").append('path')
          .each(function (d) {
            var el = d3.select(this);
            el.attr('d', scope.path).attr('stroke-opacity', 0);
            if (d.alpha2) {
              el.attr('class', d.alpha2 + " COUNTRY_KNOWN")
                .attr('tooltip-placement', 'mouse')
                .attr('tooltip-html-unsafe', ttTmpl(d.alpha2));
              $compile(this)(scope);
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
            <div class='peerid ip'>{{peer.peerid}} ({{peer.ip}})</div> \
            <div class=type>{{peer.type && peer.mode && (((peer.type|upper)+(peer.mode|upper))|i18n) || ''}}</div> \
          </div> \
          <div class=stats> \
            <div class=bps{{peer.bpsUpDn}}> \
              {{peer.bpsUp | prettyBps}} {{'UP' | i18n}}, \
              {{peer.bpsDn | prettyBps}} {{'DN' | i18n}} \
            </div> \
            <div class=bytes{{peer.bytesUpDn}}> \
              {{peer.bytesUp | prettyBytes}} {{'SENT' | i18n}}, \
              {{peer.bytesDn | prettyBytes}} {{'RECEIVED' | i18n}} \
            </div> \
            <div class=lastConnected> \
              {{!peer.connected && peer.lastConnected && 'LAST_CONNECTED' || '' | i18n }} \
              <time>{{!peer.connected && (peer.lastConnected | date:'short') || ''}}</time> \
            </div> \
          </div> \
        </div> \
      </div>";
      
      // Scaling function for our connection opacity
      var connectionOpacityScale = d3.scale.linear()
        .clamp(true).domain([0, 0]).range([0, .9]);
      
      // Functions for calculating arc dimensions
      function getTotalLength(d) { return this.getTotalLength(); }
      function getDashArray(d) { var l = this.getTotalLength(); return l+' '+l; }
      
      // Peers are uniquely identified by their peerid.
      function peerIdentifier(peer) {
        return peer.peerid
          .replace(/[.]/g, '_dot_')
          .replace(/[@]/g, '_at_')
          .replace(/[\/]/g, '_slash_')
          .replace(/[^-_0-9a-zA-z]/g, '_');
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
          .attr("tooltip-placement", "mouse")
          .attr("tooltip-html-unsafe", peerTooltipTemplate)
          .each(function(peer) {
            // Compile the tooltip target dom element to enable the tooltip-html-unsafe directive
            var childScope = scope.$new();
            childScope.peer = peer;
            $compile(this)(childScope);
          });
        
        // Create points and hover areas for each peer
        peerItems.append("path").classed("peer", true);
        peerItems.append("path").classed("peer-hover-area", true);
        
        // Configure points and hover areas on each update
        allPeers.select("g.peer path.peer").attr("d", function(peer) {
          return scope.path({type: 'Point', coordinates: [peer.lon, peer.lat]})
        }).attr("class", function(peer) {
          var result = "peer " + peer.mode + " " + peer.type;
          if (peer.connected) {
            result += " connected";
          }
          return result;
        });
        
        // Configure hover areas for all peers
        allPeers.select("g.peer path.peer-hover-area").attr("d", function(peer) {
          return scope.path({type: 'Point', coordinates: [peer.lon, peer.lat]}, 8)
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
          var oldPeer = oldPeersById[peerId];
          if (peer.connected) {
            if (!oldPeer || !oldPeer.connected) {
              if (!firstNewlyConnectedPeer) {
                newlyConnectedPeersSelector += ", ";
              }
              newlyConnectedPeersSelector += "#connection_to_" + peerId;
              firstNewlyConnectedPeer = false;
            }
          } else {
            if (!oldPeer || oldPeer.connected) {
              if (!firstNewlyDisconnectedPeer) {
                newlyDisconnectedPeersSelector += ", ";
              }
              newlyDisconnectedPeersSelector += "#connection_to_" + peerId;
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
      }
      
      // Handle model changes
      scope.$watch('model.peers', renderPeers, true);
      
      // Handle resize
      scope.$on("mapResized", function() {
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
      });
    };
  });

function VisCtrl($scope, $window, $timeout, $filter, logFactory, modelSrvc, apiSrvc) {
  var log = logFactory('VisCtrl'),
      model = modelSrvc.model,
      projection = d3.geo.mercator(),
      path = d3.geo.path().projection(projection),
      DEFAULT_POINT_RADIUS = 3;

  $scope.projection = projection;

  $scope.path = function (d, pointRadius) {
    path.pointRadius(pointRadius || DEFAULT_POINT_RADIUS);
    // https://bugs.webkit.org/show_bug.cgi?id=110691
    return path(d) || 'M0 0';
  };

  $scope.pathConnection = function (peer) {
    var pSelf = projection([model.location.lon, model.location.lat]),
        pPeer = projection([peer.lon, peer.lat]),
        xS = pSelf[0], yS = pSelf[1], xP = pPeer[0], yP = pPeer[1],
        controlPoint = [abs(xS+xP)/2, min(yS, yP) - abs(xP-xS)*0.3],
        xC = controlPoint[0], yC = controlPoint[1];
    return $scope.inGiveMode ?
      'M'+xP+','+yP+' Q '+xC+','+yC+' '+xS+','+yS :
      'M'+xS+','+yS+' Q '+xC+','+yC+' '+xP+','+yP;
  };
}
