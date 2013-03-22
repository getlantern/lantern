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
      cssClass: 'vis', // XXX hacked app/lib/bootstrap.js to look for this (search it for XXX)
      placement: 'mouse' // XXX http://stackoverflow.com/a/14761335/161642
    }
  });

function VisCtrl($scope, $window, $timeout, $filter, logFactory, modelSrvc, apiSrvc, CONFIG) {
  var log = logFactory('VisCtrl'),
      model = modelSrvc.model,
      abs = Math.abs,
      min = Math.min,
      max = Math.max,
      round = Math.round,
      dim = {},
      i18n = $filter('i18n'),
      date = $filter('date'),
      prettyUser = $filter('prettyUser'),
      prettyBps = $filter('prettyBps'),
      prettyBytes = $filter('prettyBytes'),
      $map = $('#map'),
      $$map = d3.select('#map'),
      $peers = $('#peers'),
      $$peers = d3.select('#peers'),
      $countries = $('#countries'),
      $$countries = d3.select('#countries'),
      $$self = d3.select('#self'),
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

  $scope.$watch('model.showVis', function(showVis, oldShowVis) {
    if (showVis === true) {
      $peers.tooltip(CONFIG.tooltip);
      $countries.tooltip(CONFIG.tooltip);
    } else if (showVis === false && oldShowVis) {
      $peers.tooltip('destroy');
      $countries.tooltip('destroy');
      log.debug('showVis toggled off, destroyed tooltips');
    }
  });

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
        break;
      default:
        throw new Error('Unexpected key '+key);
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
    if (model.location) drawSelf();
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
    countryPaths = $$countries.selectAll('path')
      .data(countryGeometries).enter().append('path')
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
        projection.translate([dim.width >> 1, round(0.56*dim.height)]);
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
            controlPoint = [abs(xS+xP)/2, min(yS, yP) - abs(xP-xS)*0.3],
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
    peerPaths.enter().append('path')
    peerPaths
      .attr('class', function(d) { return 'peer '+d.mode+' '+d.type; })
      .attr('id', function(d) { return d.peerid; })
      .attr('data-original-title', function(d) { return hoverContentForPeer(d); })
      .attr('d', pathPeer);
    peerPaths.exit().remove();

    var connectedPeers = _.filter(peers, 'connected'), maxBpsUpDn = 0;
    _.each(connectedPeers, function(p) { if (maxBpsUpDn < p.bpsUpDn) maxBpsUpDn = p.bpsUpDn; });
    connectionOpacityScale.domain([0, maxBpsUpDn]);
    connectionPaths = $$peers.selectAll('path.connection').data(connectedPeers, getPeerid);
    connectionPaths.enter().append('path').classed('connection', true)
      .attr('d', pathConnection)
      .attr('stroke-dashoffset', function(d) { return this.getTotalLength(); })
      .attr('stroke-dasharray', function(d) {
        var totalLength = this.getTotalLength();
        return totalLength + ' ' + totalLength;
      })
      .transition().duration(500).attr('stroke-dashoffset', 0);
    connectionPaths.style('stroke-opacity', function(d) { return connectionOpacityScale(d.bpsUpDn); });
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
    if (!model.showVis) return;
    try {
      var ctx = _.merge({
        picture: model.profile.picture,
        name: model.profile.name,
        email: model.profile.email,
        peerid: model.connectivity.peerid,
        ip: model.connectivity.ip,
        type: model.connectivity.type,
        mode: model.settings.mode,
        typeDesc: i18n(angular.uppercase(model.connectivity.type + model.settings.mode)),
        bpsUp: prettyBps(model.transfers.bpsUp)+' '+i18n('UP'),
        bpsDn: prettyBps(model.transfers.bpsDn)+' '+i18n('DN'),
        bytesUp: prettyBytes(model.transfers.bytesUp)+' '+i18n('SENT'),
        bytesDn: prettyBytes(model.transfers.bytesDn)+' '+i18n('RECEIVED'),
        lastConnectedLabel: model.connectivity.lastConnected ? i18n('LAST_CONNECTED') : '',
        lastConnected: model.connectivity.lastConnected ? date(model.connectivity.lastConnected, 'medium') : ''
      }, model.profile);
      return hoverContentForPeer.tmpl(ctx);
    } catch(e) {
      // ignore, fields probably just not populated yet
    }
  };

  function hoverContentForPeer(peer) {
    var ctx = {
      picture: 'img/default-avatar.png',
      name: '',
      email: '',
      peerid: peer.peerid,
      ip: peer.ip,
      type: peer.type,
      mode: peer.mode,
      typeDesc: i18n(angular.uppercase(peer.type + peer.mode)),
      bpsUp: peer.connected ? prettyBps(peer.bpsUp)+' '+i18n('UP') : '',
      bpsDn: peer.connected ? prettyBps(peer.bpsDn)+' '+i18n('DN') : '',
      bytesUp: prettyBytes(peer.bytesUp)+' '+i18n('SENT'),
      bytesDn: prettyBytes(peer.bytesDn)+' '+i18n('RECEIVED'),
      lastConnectedLabel: peer.connected ? '' : i18n('LAST_CONNECTED'),
      lastConnected: peer.connected ? '' : date(peer.lastConnected, 'medium')
    };
    if (peer.rosterEntry) _.merge(ctx, peer.rosterEntry);
    return hoverContentForPeer.tmpl(ctx);
  }
  hoverContentForPeer.tmpl = _.template(
    '<div class="${mode} ${type}">'+
      '<img class="picture" src="${picture}">'+
      '<div class="headers">'+
        '<div class="header">${name}</div>'+
        '<div class="email">${email}</div>'+
        '<div class="peerid ip">${peerid} (${ip})</div>'+
        '<div class="type">${typeDesc}</div>'+
      '</div>'+
      '<div class="stats">'+
        '<div class="bps">${bpsUp} ${bpsDn}</div>'+
        '<div class="bytes">${bytesUp} ${bytesDn}</div>'+
        '<div class="lastConnected">${lastConnectedLabel} <time>${lastConnected}</time></div>'+
      '</div>'+
    '</div>'
  );

  function hoverContentForCountry(alpha2, country) {
    if (!alpha2) return;
    return hoverContentForCountry.tmpl({
      countryName: i18n(alpha2),
      npeersOnlineGet: i18n('NPEERS_ONLINE_GET', country.npeers.online.get),
      npeersOnlineGive: i18n('NPEERS_ONLINE_GIVE', country.npeers.online.give),
      npeersEver: i18n('NPEERS_EVER', getByPath(country, '/npeers/ever/giveGet')||0),
      bpsUp: prettyBps(getByPath(country, '/bpsUp')||0)+' '+i18n('UP'),
      bpsDn: prettyBps(getByPath(country, '/bpsDn')||0)+' '+i18n('DN'),
      bytesUp: prettyBytes(getByPath(country, '/bytesUp')||0)+' '+i18n('UP_EVER'),
      bytesDn: prettyBytes(getByPath(country, '/bytesDn')||0)+' '+i18n('DN_EVER')
    });
  }
  hoverContentForCountry.tmpl = _.template(
    '<div class="header">${countryName}</div>'+
    '<div class="give-colored">${npeersOnlineGive}</div>'+
    '<div class="get-colored">${npeersOnlineGet}</div>'+
    '<div class="npeersEver">${npeersEver}</div>'+
    '<div class="stats">'+
      '<div class="bps">${bpsUp} ${bpsDn}</div>'+
      '<div class="bytes">${bytesUp} ${bytesDn}</div>'+
    '</div>'
  );

  function updateCountry(alpha2, peerCount, animate) {
    var stroke = CONFIG.style.countryStrokeNoActivity,
        country = getByPath(model, '/countries/'+alpha2),
        censors = country.censors,
        peersOnline = false,
        el = d3.selectAll('path.'+alpha2);
    peerCount = peerCount || getByPath(country, '/npeers/online');
    if (peerCount) {
      peersOnline = peerCount.giveGet > 0;
      if (censors) {
        if (peerCount.giveGet !== peerCount.get) {
          log.warn('npeersOnline.giveGet (', peerCount.giveGet, ') !== npeersOnline.get (', peerCount.get, ') for censoring country', alpha2);
          apiSrvc.exception({error: 'npeersInvalid', npeersOnline: peerCount, message: 'npeersOnline.giveGet ('+peerCount.giveGet+') !== npeersOnline.get ('+peerCount.get+') for censoring country'+alpha2});
        }
        stroke = CONFIG.style.getModeColor;
      } else {
        countryActivityScale.domain([-peerCount.giveGet, peerCount.giveGet]);
        var scaled = countryActivityScale(peerCount.get - peerCount.give);
        stroke = d3.rgb(giveGetColorInterpolator(scaled));
      }
    } else {
      peerCount = {give: 0, get: 0, giveGet: 0};
      country.npeers = {online: peerCount, ever: peerCount};
    }
    updateElement(el, {'stroke': stroke}, animate);
    el.attr('data-original-title', hoverContentForCountry(alpha2, country));
    el.classed('censors', censors);
    el.classed('peersOnline', peersOnline);
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
