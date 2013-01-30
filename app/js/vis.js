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
      }
    },
    source: {
      countries: 'data/countries.json'
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
  $scope.projection = projection;

  queue()
    .defer(d3.json, CONFIG.source.countries)
    .await(dataFetched);

  function dataFetched(error, countries) {
    layers.countries.selectAll('path')
      .data(countries.features)
      .enter()
      .append('path')
        .attr('d', path);
  }

  function updatePeers() {
    log.debug('updating peers');
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
}
