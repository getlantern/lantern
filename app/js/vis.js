'use strict';

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
    },
    tooltip: {
      container: 'body',
      html: true,
      selector: 'path',
      placement: 'mouse' // XXX http://stackoverflow.com/a/14761335/161642
    }
  });

function VisCtrl($scope, $window, $timeout, $filter, logFactory, modelSrvc, CONFIG, ENUMS) {
  var log = logFactory('VisCtrl'),
      model = modelSrvc.model,
      MODE = ENUMS.MODE,
      abs = Math.abs,
      min = Math.min,
      max = Math.max,
      round = Math.round,
      dim = {},
      i18n = $filter('i18n'),
      prettyUser = $filter('prettyUser'),
      prettyBytes = $filter('prettyBytes'),
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

  // disable adaptive resampling to allow projection transitions (http://bl.ocks.org/mbostock/3711652)
  //_.each(projections, function(p) { p.precision(0); });

  $scope.projectionKey = 'mercator';

  handleResize();

  $('#peers').tooltip(CONFIG.tooltip);
  $('#countries').tooltip(CONFIG.tooltip);

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

  function pathForData(d) {
    // XXX https://bugs.webkit.org/show_bug.cgi?id=110691
    return path(d) || 'M0 0';
  }

  function drawSelf() {
    path.pointRadius(CONFIG.style.pointRadiusSelf);
    $$self.attr('d', pathSelf());
    path.pointRadius(CONFIG.style.pointRadiusPeer);
  }

  function redraw() {
    globePath.attr('d', pathGlobe());
    drawSelf();
    if (peerPaths) peerPaths.attr('d', pathPeer);
    if (connectionPaths) connectionPaths.attr('d', pathConnection);
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
        .attr('rel', 'tooltip')
        .attr('class', function(d) { return d.alpha2 || 'COUNTRY_UNKNOWN'; })
        .attr('d', pathForData);
    _.each(model.countries, function(__, alpha2) { updateCountry(alpha2); });
    //borders = topojson.mesh(world, world.objects.countries, function(a, b) { return a.id !== b.id; });
  }

  function handleResize() {
    dim.width = $map.width();
    dim.height = $map.height();
    //λ.domain([-dim.width, dim.width]);
    //φ.domain([-dim.height, dim.height]);
    switch ($scope.projectionKey) {
      case 'orthographic':
        dim.radius = min(dim.width, dim.height) >> 1;
        projection.scale(dim.radius-2);
        projection.translate([dim.width >> 1, dim.height >> 1]);
        break;
      case 'mercator':
        projection.scale(max(dim.width, dim.height));
        projection.translate([dim.width >> 1, round(.56*dim.height)]);
    }
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

  var connectionOpacityScale = d3.scale.linear().clamp(true)
        .range([CONFIG.style.connectionOpacityMin, CONFIG.style.connectionOpacityMax]);

  function getPeerid(d) { return d.peerid; }

  $scope.$watch('model.peers', function(peers) {
    if (!peers) return;

    path.pointRadius(CONFIG.style.pointRadiusPeer);
    peerPaths = $$peers.selectAll('path.peer').data(peers, getPeerid);
    peerPaths.enter().append('path').classed('peer', true);
    peerPaths
      .classed('give', function(d) { return d.mode === MODE.give; })
      .classed('get', function(d) { return d.mode === MODE.get; })
      .attr('id', function(d) { return d.peerid; })
      .attr('data-original-title', function(d) { return hoverContentForPeer(d); })
      .attr('d', pathPeer);
    peerPaths.exit().remove();

    var connectedPeers = _.filter(peers, 'connected'), maxBpsUpDn = 0;
    _.each(connectedPeers, function(p) { if (maxBpsUpDn < p.bpsUpDn) maxBpsUpDn = p.bpsUpDn; });
    connectionOpacityScale.domain([0, maxBpsUpDn]);
    connectionPaths = $$peers.selectAll('path.connection').data(connectedPeers, getPeerid);
    connectionPaths.enter().append('path').classed('connection', true);
    connectionPaths.attr('d', pathConnection)
      .style('stroke-opacity', function(d) { return connectionOpacityScale(d.bpsUpDn); });
    connectionPaths.exit().remove();
  }, true);

  var maxGiveGet = 0,
      countryOpacityScale = d3.scale.linear().clamp(true)
        .range([CONFIG.style.countryOpacityMin, CONFIG.style.countryOpacityMax]),
      countryActivityScale = d3.scale.linear().clamp(true),
      giveGetColorInterpolator = d3.interpolateRgb(CONFIG.style.giveModeColor,
                                                   CONFIG.style.getModeColor);

  function updateElement(el, update, animate, duration) {
    if (animate) el.classed('updating', true);
    if (_.isFunction(update)) {
      update();
    } else if (_.isPlainObject(update)) {
      _.each(update, function(v, k) { el.style(k, v); });
    } else {
      log.error('invalid update: expected function or object, got', typeof update);
    }
    if (animate) setTimeout(function() { el.classed('updating', false); }, duration || 500);
  }

  $scope.hoverContentForSelf = function() {
    var ctx = _.merge({
      peerid: model.connectivity.peerid,
      mode: model.settings.mode,
      bytesUp: prettyBytes(model.transfers.bytesUp)+' '+i18n('SENT'),
      bytesDn: prettyBytes(model.transfers.bytesDn)+' '+i18n('RECEIVED'),
    }, model.profile);
    return hoverContentForPeer.onRosterTemplate(ctx);
  };

  function hoverContentForPeer(peer) {
    var ctx = {
      peerid: peer.peerid,
      mode: peer.mode,
      bytesUp: prettyBytes(peer.bytesUp)+' '+i18n('SENT'),
      bytesDn: prettyBytes(peer.bytesDn)+' '+i18n('RECEIVED'),
    }, tmpl;
    if (peer.rosterEntry) {
      _.merge(ctx, peer.rosterEntry);
      tmpl = hoverContentForPeer.onRosterTemplate;
    } else {
      tmpl = hoverContentForPeer.notOnRosterTemplate;
    }
    return tmpl(ctx);
  }
  hoverContentForPeer.onRosterTemplate = _.template(
    '<div class="visTooltip ${mode}-mode">'+
    '<img class="picture pull-left" src="${picture}">'+
    '<h5>${name}</h5>'+
    '<div class="email">${email}</div>'+
    '<div class="peerid">${peerid}</div>'+
    '<span class="bytesUp">${bytesUp}</span>'+
    '<span class="bytesDn">${bytesDn}</span>'+
    '</div>'
  );
  hoverContentForPeer.notOnRosterTemplate = _.template(
    '<div class="visTooltip ${mode}-mode">'+
    '<h5>${peerid}</h5>'+
    '<span class="bytesUp">${bytesUp}</span>'+
    '<span class="bytesDn">${bytesDn}</span>'+
    '</div>'
  );

  function hoverContentForCountry(alpha2, peerCount) {
    if (!alpha2) return;
    return hoverContentForCountry.template({
      countryName: i18n(alpha2),
      npeersOnlineGet: i18n('NPEERS_ONLINE_GET', peerCount.get),
      npeersOnlineGive: i18n('NPEERS_ONLINE_GIVE', peerCount.give)
    });
  }
  hoverContentForCountry.template = _.template(
    '<div class="visTooltip">'+
    '<h5>${countryName}</h5>'+
    '<div class="give-colored">${npeersOnlineGive}</div>'+
    '<div class="get-colored">${npeersOnlineGet}</div>'+
    '</div>'
  );

  function updateCountry(alpha2, peerCount, animate) {
    var stroke = CONFIG.style.countryStrokeNoActivity, strokeOpacity;
    peerCount = peerCount || getByPath(model, '/countries/'+alpha2+'/npeers/online');
    if (peerCount) {
      var censors = getByPath(model, '/countries/'+alpha2).censors;
      if (censors) {
        if (peerCount.giveGet !== peerCount.get) {
          log.warn('peerCount.giveGet (', peerCount.giveGet, ') !== peerCount.get (', peerCount.get, ') for censoring country', alpha2);
          // XXX POST to exceptional notifier
        }
        stroke = CONFIG.style.getModeColor;
      } else {
        countryActivityScale.domain([-peerCount.giveGet, peerCount.giveGet]);
        var scaled = countryActivityScale(peerCount.get - peerCount.give);
        stroke = d3.rgb(giveGetColorInterpolator(scaled));
      }
      strokeOpacity = .1;
    } else {
      strokeOpacity = 0;
      peerCount = {give: 0, get: 0, giveGet: 0};
    }
    var el = d3.select('path.'+alpha2);
    updateElement(el, {'stroke': stroke, 'stroke-opacity': strokeOpacity}, animate);
    el.attr('data-original-title', function(d) { return hoverContentForCountry(alpha2, peerCount); })
  }

  var unwatchAllCountries = $scope.$watch('model.countries', function(countries) {
    if (!countries) return;
    unwatchAllCountries();
    _.each(countries, function(__, alpha2) {
      $scope.$watch('model.countries.'+alpha2+'.npeers.online', function(peerCount, peerCountOld) {
        if (!peerCount) return;
        if (peerCount.giveGet > maxGiveGet) {
          maxGiveGet = peerCount.giveGet;
          countryOpacityScale.domain([0, maxGiveGet]);
          if (countryPaths) _.each(countries, function(__, alpha2) { updateCountry(alpha2); });
        } else if (peerCount && !_.isEqual(peerCount, peerCountOld)) {
          if (countryPaths) updateCountry(alpha2, peerCount, true);
        }
      }, true);
    });
  }, true);

  // XXX show last seen locations of peers not connected to
}
