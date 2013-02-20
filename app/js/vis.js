'use strict';

angular.module('app.vis', [])
  .constant('CONFIG', {
    //scale: 1400,
    scale: 248,
    clipAngle: 87,
    //translate: [500, 350],
    style: {
      giveModeColor: '#00ff80',
      getModeColor: '#ffcc66',
      countryOpacityMin: 0,
      countryOpacityMax: .5,
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
      //projection = d3.geo.mercator()
      //               .scale(CONFIG.scale)
      //               .translate(CONFIG.translate),
      projection = d3.geo.orthographic()
                     .scale(CONFIG.scale)
                     .clipAngle(CONFIG.clipAngle),
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

  $scope.fillByCountry = {};
  var maxGiveGet = 0,
      countryOpacityScale = d3.scale.linear()
                              .range([CONFIG.style.countryOpacityMin, CONFIG.style.countryOpacityMax])
                              .clamp(true),
      countryFillScale = d3.scale.linear(),
      GMC = d3.rgb(CONFIG.style.getModeColor),
      getModeColorPrefix = 'rgba('+GMC.r+','+GMC.g+','+GMC.b+',',
      countryFillInterpolator = d3.interpolateRgb(CONFIG.style.giveModeColor,
                                                  CONFIG.style.getModeColor);

  function updateFill(country) {
    var npeers = getByPath(model, '/countries/'+country+'/npeers/online');
    if (!npeers) return;
    var censors = getByPath(model, '/countries/'+country).censors,
        scaledOpacity = countryOpacityScale(npeers.giveGet),
        colorPrefix, fill;
    if (censors) {
      if (npeers.giveGet !== npeers.get) {
        log.warn('npeers.giveGet (', npeers.giveGet, ') !== npeers.get (', npeers.get, ') for censoring country', country);
      }
      colorPrefix = getModeColorPrefix;
    } else {
      countryFillScale.domain([-npeers.giveGet, npeers.giveGet]);
      var scaledFill = countryFillScale(npeers.get - npeers.give),
          color = d3.rgb(countryFillInterpolator(scaledFill));
      colorPrefix = 'rgba('+color.r+','+color.g+','+color.b+',';
    }
    fill = colorPrefix+(scaledOpacity||0)+')';
    $scope.fillByCountry[country] = fill;
    //log.debug('updated fill for country', country, 'to', fill);
  }

  var unwatchAllCountries = $scope.$watch('model.countries', function(countries) {
    if (!countries) return;
    unwatchAllCountries();
    _.forEach(countries, function(stats, country) {
      $scope.$watch('model.countries.'+country+'.npeers.online', function(npeers) {
        if (!npeers) return;
        if (npeers.giveGet > maxGiveGet) {
          maxGiveGet = npeers.giveGet;
          countryOpacityScale.domain([0, maxGiveGet]);
          _.forEach(countries, updateFill);
        } else {
          updateFill(country);
        }
      }, true);
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
