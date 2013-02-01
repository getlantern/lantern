'use strict';

angular.module('app.vis', [])
  .constant('CONFIG', {
    scale: 1400,
    translate: [500, 350],
    style: {
      self: {
        r: 5
      },
      peer: {
        r: 3
      },
      connection: {
        heightFactor: .3
      }
    },
    source: {
      world: 'data/world.json'
    }
  });

function VisCtrl($scope, $window, logFactory, modelSrvc, CONFIG) {
  var log = logFactory('VisCtrl'),
      model = modelSrvc.model,
      projection = d3.geo.mercator()
                     .scale(CONFIG.scale)
                     .translate(CONFIG.translate),
      path = d3.geo.path().projection(projection),
      zoom = d3.behavior.zoom(),
      svg = d3.select('svg'),
      layers = {
        countries: svg.select('#countries'),
        self: svg.select('#self')
      };

  $scope.CONFIG = CONFIG;
  $scope.project = function(latlon) {
    if (!latlon) return latlon;
    var p = projection([latlon.lon, latlon.lat]);
    return {x: p[0], y: p[1]};
  };

  $scope.selfR = CONFIG.style.self.r;
  $scope.peerR = CONFIG.style.peer.r;

  var abs = Math.abs,
      min = Math.min,
      heightFactor = CONFIG.style.connection.heightFactor;

  queue()
    .defer(d3.json, CONFIG.source.world)
    .await(dataFetched);

  $scope.countryPaths = {};
  function dataFetched(error, world) {
    $scope.countryGeometries = topojson.object(world, world.objects.countries).geometries;
    var paths = $scope.countryPaths, geoms = $scope.countryGeometries;
    for (var i=0, d=geoms[i]; d; d=geoms[++i]) {
      paths[d.alpha2] = path(d);
    }
  }

  function redraw() {
    log.debug('in redraw');
    var scale     = d3.event.scale,
        translate = d3.event.translate;
    zoom.translate();
    svg.attr('transform', 'translate(' + translate + ') scale(' + scale + ')');
    // resize, recenter, redraw
  }
  //d3.select($window).on('resize', redraw); // XXX

  $scope.$watch('model.location', function(loc) {
    if (!loc) return;
    $scope.self = $scope.project(loc);
  }, true);

  $scope.opacityByCountry = {};
  var countryOpacityScale = d3.scale.linear()
                              .domain([0, 1000])
                              .range([0, .2])
                              .clamp(true);

  var unwatchAllCountries = $scope.$watch('model.countries', function(countries) {
    if (!countries) return;
    unwatchAllCountries();
    _.forEach(countries, function(stats, country) {
      $scope.$watch('model.countries.'+country+'.nusers.online', function(nusers) {
        $scope.opacityByCountry[country] = countryOpacityScale(nusers) || 0;
      });
    });
  }, true);

  function _controlpoint(x1, y1, x2, y2) {
    return {x: abs(x1 + x2) / 2,
            y: min(y2, y1) - abs(x2 - x1) * heightFactor};
  }

  $scope.controlpoint = function(peer) {
    if (!peer) return peer;
    var projected = $scope.project(peer);
    return _controlpoint($scope.self.x, $scope.self.y, projected.x, projected.y);
  };
}
