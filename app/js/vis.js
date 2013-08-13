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
        d3.select(element[0]).selectAll('path').data(f).enter().append('path')
          .each(function (d) {
            var el = d3.select(this);
            el.attr('d', scope.path).attr('stroke-opacity', 0);
            if (d.alpha2) {
              el.attr('class', d.alpha2)
                .attr('tooltip-placement', 'mouse')
                .attr('tooltip-html-unsafe', ttTmpl(d.alpha2));
              $compile(this)(scope);
              scope.$watch('model.countries.'+d.alpha2, function (newVal, oldVal) {
                var npeersOnline = getByPath(newVal, '/npeers/online/giveGet') || 0,
                    oldNpeersOnline = getByPath(oldVal, '/npeers/online/giveGet') || 0,
                    updated = npeersOnline !== oldNpeersOnline;
                if (npeersOnline > maxNpeersOnline) {
                  maxNpeersOnline = npeersOnline;
                }
                strokeOpacityScale.domain([0, maxNpeersOnline]);
                el.attr('stroke-opacity', strokeOpacityScale(npeersOnline));
                if (oldVal && updated) {
                  el.classed('updating', true);
                  $timeout(function () {
                    el.classed('updating', false);
                  }, 500);
                }
              }, true);
            } else {
              el.attr('class', 'COUNTRY_UNKNOWN');
            }
          });
      });
    };
  })
  .directive('watchConnections', function () {
    return function (scope, element) {
      scope.connectionOpacityScale = d3.scale.linear()
        .clamp(true).domain([0, 0]).range([0, .9]);

      scope.$watch('model.peers', function(peers) {
        if (!peers) return;

        var maxBpsUpDn = 0;

        _.each(peers, function (p) {
          if (maxBpsUpDn < p.bpsUpDn)
            maxBpsUpDn = p.bpsUpDn;
        });

        if (maxBpsUpDn !== scope.connectionOpacityScale.domain()[1]) {
          scope.connectionOpacityScale.domain([0, maxBpsUpDn]);
        }
      }, true);
    };
  })
  .directive('animateConnection', function () {

    function getTotalLength(d) { return this.getTotalLength(); }
    function getDashArray(d) { var l = this.getTotalLength(); return l+' '+l; }

    return function (scope, element) {
      element = d3.select(element[0]);
      scope.$watch('peer.connected', function(newVal, oldVal) {
        if (!newVal === !oldVal) return;
        element
          .transition().duration(500)
          .each('start', function() {
            element
              .attr('stroke-dashoffset', newVal ? getTotalLength : 0)
              .attr('stroke-dasharray', getDashArray)
          })
          .attr('stroke-dashoffset', newVal ? 0 : getTotalLength);
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
