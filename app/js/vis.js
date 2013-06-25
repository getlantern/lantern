'use strict';

var PI = Math.PI,
    TWO_PI = 2 * PI,
    abs = Math.abs,
    min = Math.min,
    max = Math.max,
    round = Math.round;

angular.module('app.vis', [])
  .constant('CONFIG', {
    style: {
      connectionOpacityMin: .1,
      connectionOpacityMax: 1,
      countryOpacityMin: .01,
      countryOpacityMax: .2,
      countryOpacityNoActivity: .2,
      countryStrokeNoActivity: 'rgb(30, 61, 75)',
      giveModeColor: '#aad092',
      getModeColor: '#ffcc66',
      pointRadiusSelf: 5,
      pointRadiusPeer: 3
    },
    source: {
      world: 'data/world.json'
    }
  })
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
  .directive('countries', function (CONFIG, $compile) {

    function ttTmpl(d) {
      var alpha2 = d.alpha2;
      return '<div class="vis">'+
        '<div class="header">{{ "'+alpha2+'" | i18n }}</div>'+
        '<div class="give-colored">{{ "NPEERS_ONLINE_GIVE" | i18n:model.countries.'+alpha2+'.npeers.online.give }}</div>'+
        '<div class="get-colored">{{ "NPEERS_ONLINE_GET" | i18n:model.countries.'+alpha2+'.npeers.online.get }}</div>'+
        '<div class="npeersEver">{{ "NUSERS_EVER" | i18n:model.countries.'+alpha2+'.nusers.ever }}</div>'+
        '<div class="stats">'+
          '<div class="bps">'+
            '{{ model.countries.'+alpha2+'.bpsUp || 0 | prettyBps }} {{ "UP" | i18n }} '+
            '{{ model.countries.'+alpha2+'.bpsDn || 0 | prettyBps }} {{ "DN" | i18n }}'+
          '</div>'+
          '<div class="bytes">'+
            '{{ model.countries.'+alpha2+'.bytesUp || 0 | prettyBps }} {{ "UP_EVER" | i18n }} '+
            '{{ model.countries.'+alpha2+'.bytesDn || 0 | prettyBps }} {{ "DN_EVER" | i18n }}'+
          '</div>'+
        '</div>'+
      '</div>';
    }

    return function (scope, element) {
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

      d3.json(CONFIG.source.world, function (error, world) {
        if (error) throw error;
        //var f = topojson.feature(world, world.objects.countries).features;
        var f = topojson.object(world, world.objects.countries).geometries;
        d3.select(element[0]).selectAll('path').data(f).enter().append('path')
          .attr('class', function(d){ return d.alpha2 || 'COUNTRY_UNKNOWN'; })
          .attr('tooltip-placement', 'mouse')
          .attr('tooltip-html-unsafe', ttTmpl)
          .attr('d', scope.path)
          .each(function(){ $compile(this)(scope); });
      });
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

function VisCtrl($scope, $window, $timeout, $filter, logFactory, modelSrvc, apiSrvc, CONFIG) {
  var log = logFactory('VisCtrl'),
      model = modelSrvc.model,
      i18n = $filter('i18n'),
      date = $filter('date'),
      prettyBps = $filter('prettyBps'),
      prettyBytes = $filter('prettyBytes'),
      projection = d3.geo.mercator(),
      path = d3.geo.path().projection(projection),
      pathSelf = d3.geo.path().projection(projection);

  path.pointRadius(CONFIG.style.pointRadiusPeer);
  pathSelf.pointRadius(CONFIG.style.pointRadiusSelf);

  $scope.path = function (d, self) {
    // https://bugs.webkit.org/show_bug.cgi?id=110691
    return (self ? pathSelf : path)(d) || 'M0 0';
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

  $scope.projection = projection;

  $scope.connectionOpacityScale = d3.scale.linear().clamp(true)
    .range([CONFIG.style.connectionOpacityMin, CONFIG.style.connectionOpacityMax]);

  $scope.$watch('model.peers', function(peers) {
    if (!peers) return;

    var connectedPeers = _.filter(peers, 'connected'), maxBpsUpDn = 0;
    _.each(connectedPeers, function(p) { if (maxBpsUpDn < p.bpsUpDn) maxBpsUpDn = p.bpsUpDn; });
    $scope.connectionOpacityScale.domain([0, maxBpsUpDn]);
  }, true);
  
}
