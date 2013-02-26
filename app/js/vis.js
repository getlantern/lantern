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

function VisCtrl($scope, $window, $timeout, $filter, logFactory, modelSrvc, CONFIG, ENUMS) {
  var log = logFactory('VisCtrl'),
      model = modelSrvc.model,
      MODE = ENUMS.MODE,
      abs = Math.abs,
      min = Math.min,
      dim = {},
      $map = $('#map'),
      $$map = d3.select('#map'),
      $$self = d3.select('#self'),
      $$peers = d3.select('#peers'),
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
      globePath = d3.select('#globe'),
      countryPaths, peerPaths, connectionPaths,
      //dragging = false, lastX, lastY,
      redrawThrottled = _.throttle(redraw, 500);

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

  function drawSelf() {
    path.pointRadius(CONFIG.style.pointRadiusSelf);
    $$self.attr('d', pathSelf());
  }

  function redraw() {
    globePath.attr('d', pathGlobe());
    drawSelf();
    if (peerPaths) {
      path.pointRadius(CONFIG.style.pointRadiusPeer);
      peerPaths.attr('d', pathPeer);
    }
    if (connectionPaths) {
      connectionPaths.attr('d', pathConnection);
    }
    if (countryPaths) countryPaths.attr('d', pathForData);
  }

  /*
  $$map.call(zoom).on('mousedown', function() {
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
    redrawThrottled();
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
    dim.width = $map.width();
    dim.height = $map.height();
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
    redrawThrottled();
  }
  d3.select($window).on('resize', handleResize);

  /*
  // XXX recenter around cursor
  // XXX look at http://bl.ocks.org/mbostock/4987520
  function handleZoom() {
    projection.scale(d3.event.scale);
    redraw();
  }
  */

  function pathGlobe() {
    return path({type: 'Sphere'});
  }

   function pathConnection(peer) {
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
  }

  function pathPeer(peer) {
    return path({type: 'Point', coordinates: [peer.lon, peer.lat]});
  }

  function pathSelf() {
    return path({type: 'Point', coordinates: [model.location.lon, model.location.lat]});
  }

  $scope.$watch('model.location', function(loc) {
    if (!loc) return;
    if ($scope.projectionKey === 'orthographic') projection.rotate([-loc.lon, 0]);
    drawSelf();
  }, true);

  function getPeerid(d) { return d.peerid; }
  $scope.$watch('model.connectivity.peers.current', function(peers) {
    if (!peers) return;
    path.pointRadius(CONFIG.style.pointRadiusPeer);
    peerPaths = $$peers.selectAll('path.peer').data(peers, getPeerid);
    peerPaths.enter().append('path').classed('peer', true);
    peerPaths
      .classed('give', function(d) { return d.mode === MODE.give; })
      .classed('get', function(d) { return d.mode === MODE.get; })
      .attr('id', function(d) { return d.peerid; })
      .attr('d', pathPeer);
    peerPaths.exit().remove();

    connectionPaths = $$peers.selectAll('path.connection').data(peers, getPeerid);
    connectionPaths.enter().append('path').classed('connection', true);
    connectionPaths.attr('d', pathConnection);
    connectionPaths.exit().remove();
  }, true);

  var maxGiveGet = 0,
      countryOpacityScale = d3.scale.linear().clamp(true)
        .range([CONFIG.style.countryOpacityMin, CONFIG.style.countryOpacityMax]),
      countryFillScale = d3.scale.linear().clamp(true),
      countryFillInterpolator = d3.interpolateRgb(CONFIG.style.giveModeColor,
                                                  CONFIG.style.getModeColor);

  function updateElement(el, update, duration) {
    el.classed('updating', true);
    if (_.isFunction(update)) {
      update();
    } else if (_.isPlainObject(update)) {
      _.each(update, function(v, k) { el.style(k, v); });
    } else {
      log.error('invalid update: expected function or object, got', typeof update);
    }
    setTimeout(function() { el.classed('updating', false); }, duration || 500);
  }

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
    updateElement(d3.select('path.'+country), {'fill': fill});
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
