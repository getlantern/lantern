'use strict';

angular.module('app.vis', [])
  .constant('CONFIG', {
    style: {
      countryOpacityMax: .5,
      countryOpacityMin: .1,
      countryBaseColor: 'rgba(0, 0, 0, .1)',
      giveModeColor: '#00ff80',
      getModeColor: '#ffcc66',
    },
    source: {
      world: 'data/world.json'
    }
  });

function VisCtrl($scope, $window, $timeout, $filter, logFactory, modelSrvc, CONFIG) {
  var log = logFactory('VisCtrl'),
      model = modelSrvc.model,
      abs = Math.abs,
      min = Math.min,
      dim = {},
      $svg = $('#vis svg'),
      projections = {
        orthographic: d3.geo.orthographic().clipAngle(90),
        mercator: d3.geo.mercator()
      },
      projection = projections['mercator'],
      λ = d3.scale.linear().range([-180, 180]),
      φ = d3.scale.linear().range([90, -90]),
      zoom = d3.behavior.zoom().scaleExtent([50, 1000]).on('zoom', handleZoom),
      path = d3.geo.path().projection(projection),
      greatArc = d3.geo.greatArc(),
      dragging = false, lastX, lastY;

  // disable adaptive resampling to allow transitions (http://bl.ocks.org/mbostock/3711652)
  _.each(projections, function(p) { p.precision(0); });

  $scope.projectionKey = 'mercator';
  $scope.path = path;
  $scope.countryBaseColor = CONFIG.style.countryBaseColor;

  $scope.setProjection = function(key) {
    if (!(key in projections)) {
      log.error('invalid projection:', key);
      return;
    }
    $scope.projectionKey = key;
    projection = projections[key];
    path.projection(projection);
  };

  d3.select('#vis svg').call(zoom).on('mousedown', function() {
    dragging = true;
    lastX = d3.event.x;
    lastY = d3.event.y;
  }).on('mousemove', function() {
    if (!dragging) return;
    var dx = d3.event.x - lastX,
        dy = d3.event.y - lastY;
    switch ($scope.projectionKey) {
      case 'orthographic':
        var current = projection.rotate();
        projection.rotate([current[0]+λ(dx), current[1]+φ(dy)]);
        break;
      case 'mercator':
        // XXX
    }
    lastX = d3.event.x;
    lastY = d3.event.y;
    $scope.$apply();
  }).on('mouseup', function() {
    dragging = false;
  });

  //function rotateWest() {
  //  projection.rotate([-λ(velocity * (Date.now() - then)), 0]);
  //}
  //d3.timer(rotateWest);

  queue()
    .defer(d3.json, CONFIG.source.world)
    .await(dataFetched);

  function dataFetched(error, world) {
    $scope.countryGeometries = topojson.object(world, world.objects.countries).geometries;
    //borders = topojson.mesh(world, world.objects.countries, function(a, b) { return a.id !== b.id; });
  }

  // XXX this clobbers any zooming and panning the user did on resize
  function handleResize() {
    dim.width = $svg.width();
    dim.height = $svg.height();
    λ.domain([-dim.width, dim.width]);
    φ.domain([-dim.height, dim.height]);
    switch ($scope.projectionKey) {
      case 'orthographic':
        dim.radius = Math.min(dim.width, dim.height) >> 1;
        projection.scale(dim.radius-2);
        break;
      case 'mercator':
        projection.scale(Math.min(dim.width, dim.height));
    }
    projection.translate([dim.width/2, dim.height/2]);
    zoom.scale(projection.scale());
  }
  handleResize();
  d3.select($window).on('resize', handleResize);

  // XXX look at http://bl.ocks.org/mbostock/4987520
  function handleZoom() {
    projection.scale(d3.event.scale);
    $scope.$apply();
  }

  $scope.pathGlobe = function() {
    return path({type: 'Sphere'});
  };

  $scope.pathConnection = function(peer) {
    switch ($scope.projectionKey) {
      case 'orthographic':
        return path(greatArc({source: [model.location.lon, model.location.lat], target: [peer.lon, peer.lat]}));
      case 'mercator':
        var pSelf = projection([model.location.lon, model.location.lat]),
            pPeer = projection([peer.lon, peer.lat]),
            xS = pSelf[0], yS = pSelf[1], xP = pPeer[0], yP = pPeer[1],
            controlPoint = [abs(xS+xP)/2, min(yS, yP) - abs(xP-xS)*.3],
            xC = controlPoint[0], yC = controlPoint[1];
        return 'M'+xS+' '+yS+'Q'+xC+' '+yC+' '+xP+' '+yP;
    }
  };

  $scope.pathPeer = function(peer) {
    return path({type: 'Point', coordinates: [peer.lon, peer.lat]});
  };

  $scope.pathSelf = function() {
    return path({type: 'Point', coordinates: [model.location.lon, model.location.lat]});
  };

  $scope.$watch('model.location', function(loc) {
    if (!loc) return;
    projection.rotate([-loc.lon, 0]);
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
    _.each(countries, function(stats, country) {
      $scope.$watch('model.countries.'+country+'.npeers.online', function(npeers) {
        if (!npeers) return;
        if (npeers.giveGet > maxGiveGet) {
          maxGiveGet = npeers.giveGet;
          countryOpacityScale.domain([0, maxGiveGet]);
          _.each(countries, updateFill);
        } else {
          updateFill(country);
        }
      }, true);
    });
  }, true);

  // XXX show last seen locations of peers not connected to
}
