'use strict';

var PI = Math.PI,
    TWO_PI = 2 * PI,
    abs = Math.abs,
    min = Math.min,
    max = Math.max,
    round = Math.round;

angular.module('app.vis', [])
  .directive('fullwindow', function ($window) {
    return function (scope, element) {
      function size() {
        var w = element.width(), h = element.height();
        scope.projection.scale(max(w, h) / TWO_PI);
        scope.projection.translate([w >> 1, round(0.56*h)]);
      }
      size();
      angular.element($window).bind('resize', _.throttle(function () {
        size();
        d3.selectAll('#countries path').attr('d', scope.path);
        d3.selectAll('path.connection')
          .attr('stroke-dashoffset', null)
          .attr('stroke-dasharray', null);
        scope.$digest();
      }, 500));
    };
  })
  .directive('globe', function () {
    return function (scope, element) {
      var d = scope.path({type: 'Sphere'});
      element.attr('d', d);
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
      
      scope.$watch('model.countries', function (newCountries, oldCountries) {
        console.log("Countries changed");
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
              changedCountriesSelector += ",";
            }
            changedCountriesSelector += "." + countryCode;
            firstChangedCountry = false;
          }
        }
        
        // Update opacity for all known countries
        strokeOpacityScale.domain([0, maxNpeersOnline]);
        d3.select(element[0]).selectAll("path.COUNTRY_KNOWN").attr('stroke-opacity', function(d) {
          strokeOpacityScale(npeersOnlineByCountry[d.alpha2] || 0);
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
  .directive('peers', function ($compile) {
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
        return peer.peerid;
      }
      
      var peersContainer = d3.select(element[0]);
      
      scope.$watch('model.peers', function(peers) {
        if (!peers) return;
      
        // Figure out our maxBps
        var maxBpsUpDn = 0;
        _.each(peers, function (p) {
          if (maxBpsUpDn < p.bpsUpDn)
            maxBpsUpDn = p.bpsUpDn;
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
        
        // Handle animation of connecting/disconnecting peers
        // Repopulate list of connected peers
        var connectedPeers = [];
        peers.forEach(function(peer) {
          if (peer.connected) {
            connectedPeers.push(peer);
          }
        });
        
        var allArcs = allPeers.selectAll("path.connection").data(function(peer) {
          if (peer.connected) {
            return [peer];
          } else {
            return [];
          }
        } , peerIdentifier);
        var newlyConnectedArcs = allArcs.enter();
        var disconnectedArcs = allArcs.exit();
        
        // Add arcs to new peers
        newlyConnectedArcs.append("path").classed("connection", true).attr("stroke-opacity", function(peer) {
            return connectionOpacityScale(peer.bpsUpDn);
          })
          .attr("d", scope.pathConnection)
          .transition().duration(500)
            .each('start', function() {
              d3.select(this)
                .attr('stroke-dashoffset', getTotalLength)
                .attr('stroke-dasharray', getDashArray)
            }).attr('stroke-dashoffset', 0);
        
        disconnectedArcs.transition().duration(500)
          .each('start', function() {
            d3.select(this)
              .attr('stroke-dashoffset', 0)
              .attr('stroke-dasharray', getDashArray)
          }).attr('stroke-dashoffset', getTotalLength)
          .remove();
        
        // Remove departed peers
        departedPeers.remove();
        
      }, true);
    };
  })

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
