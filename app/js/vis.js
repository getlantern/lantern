'use strict';

angular.module('app.vis', [])
  .constant('CONFIG', {
    style: {
      countryOpacityMax: .25,
      countryOpacityMin: .1,
      giveModeColor: '#aad092',
      getModeColor: '#ffcc66',
      pointRadiusSelf: 5,
      pointRadiusPeer: 3
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
      //λ = d3.scale.linear().range([-180, 180]).clamp(true),
      //φ = d3.scale.linear().range([-90, 90]).clamp(true),
      //zoom = d3.behavior.zoom().on('zoom', handleZoom),
      path = d3.geo.path().projection(projection),
      greatArc = d3.geo.greatArc(),
      countryPaths;
      //dragging = false, lastX, lastY;

  // disable adaptive resampling to allow transitions (http://bl.ocks.org/mbostock/3711652)
  _.each(projections, function(p) { p.precision(0); });

  $scope.projectionKey = 'mercator';

  handleResize();

  /*
  $scope.setProjection = function(key) {
    if (!(key in projections)) {
      log.error('invalid projection:', key);
      return;
    }
    // XXX check this:
    switch (key) {
      case 'mercator':
        φ.range([-90, 90]);
        break;
      case 'orthographic':
        φ.range([90, -90]);
    }
    $scope.projectionKey = key;
    projection = projections[key];
    path.projection(projection);
    handleResize();
  };
  */

  function pathForData(d) {
    // XXX https://bugs.webkit.org/show_bug.cgi?id=110691
    return path(d) || 'M0 0';
  }

  function updateCountryPaths() {
    countryPaths.attr('d', pathForData);
  }

  /*
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
        var current = projection.translate();
        projection.translate([current[0]+dx, current[1]+dy]);
    }
    lastX = d3.event.x;
    lastY = d3.event.y;
    updateCountryPaths();
  }).on('mouseup', function() {
    dragging = false;
  });
  */

  //function rotateWest() {
  //  projection.rotate([-λ(velocity * (Date.now() - then)), 0]);
  //}
  //d3.timer(rotateWest);

  queue()
    .defer(d3.json, CONFIG.source.world)
    .await(dataFetched);

  function dataFetched(error, world) {
    var countryGeometries = topojson.object(world, world.objects.countries).geometries;
    countryPaths = d3.select('#countries').selectAll('path')
      .data(countryGeometries).enter().append('path')
        .attr('class', function(d) { return d.alpha2; })
        .attr('d', pathForData);
    //borders = topojson.mesh(world, world.objects.countries, function(a, b) { return a.id !== b.id; });
  }

  function handleResize() {
    dim.width = $svg.width();
    dim.height = $svg.height();
    //λ.domain([-dim.width, dim.width]);
    //φ.domain([-dim.height, dim.height]);
    switch ($scope.projectionKey) {
      case 'orthographic':
        dim.radius = Math.min(dim.width, dim.height) >> 1;
        projection.scale(dim.radius-2);
        break;
      case 'mercator':
        projection.scale(Math.max(dim.width, dim.height));
    }
    projection.translate([dim.width >> 1, dim.height >> 1]);
    //zoom.scale(projection.scale());
    if (countryPaths) updateCountryPaths();
  }
  d3.select($window).on('resize', handleResize);

  /*
  // XXX recenter around cursor
  // XXX look at http://bl.ocks.org/mbostock/4987520
  function handleZoom() {
    projection.scale(d3.event.scale);
    updateCountryPaths();
  }
  */

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
    path.pointRadius(CONFIG.style.pointRadiusPeer);
    return path({type: 'Point', coordinates: [peer.lon, peer.lat]});
  };

  $scope.pathSelf = function() {
    path.pointRadius(CONFIG.style.pointRadiusSelf);
    return path({type: 'Point', coordinates: [model.location.lon, model.location.lat]});
  };

  $scope.$watch('model.location', function(loc) {
    if (!loc) return;
    if ($scope.projectionKey === 'orthographic') projection.rotate([-loc.lon, 0]);
  }, true);

  var maxGiveGet = 0,
      countryOpacityScale = d3.scale.linear().clamp(true)
        .range([CONFIG.style.countryOpacityMin, CONFIG.style.countryOpacityMax]),
      countryFillScale = d3.scale.linear().clamp(true),
      countryFillInterpolator = d3.interpolateRgb(CONFIG.style.giveModeColor,
                                                  CONFIG.style.getModeColor);

  function updateFill(country) {
    var npeers = getByPath(model, '/countries/'+country+'/npeers/online');
    if (!npeers) return;
    var censors = getByPath(model, '/countries/'+country).censors,
        scaledOpacity = countryOpacityScale(npeers.giveGet),
        fill;
    if (censors) {
      fill = CONFIG.style.getModeColor;
      if (npeers.giveGet !== npeers.get) {
        log.warn('npeers.giveGet (', npeers.giveGet, ') !== npeers.get (', npeers.get, ') for censoring country', country);
        // XXX POST to exceptional notifier
      }
    } else {
      countryFillScale.domain([-npeers.giveGet, npeers.giveGet]);
      var scaledFill = countryFillScale(npeers.get - npeers.give);
      fill = d3.rgb(countryFillInterpolator(scaledFill));
    }
    var element = d3.select('path.'+country);
    element.classed('updating', true).style('fill', fill);
    setTimeout(function() { element.classed('updating', false); }, 500);
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
