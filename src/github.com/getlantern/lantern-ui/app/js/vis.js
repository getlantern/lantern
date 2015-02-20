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
              var $content = ttTmpl(d.alpha2);

              el.attr('class', d.alpha2 + " COUNTRY_KNOWN")
                .attr('tooltip-placement', 'mouse')
                .attr('tooltip-html-unsafe', $content);
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
