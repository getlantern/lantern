'use strict';

angular.module('app.vis', [])
  // http://en.wikipedia.org/wiki/Censorship_by_country
  // XXX factor out into a data source?
  .constant('COUNTRIES_CENSORED', ["China", "Cuba", "Iran", "Myanmar", "Syria", "Turkmenistan", "Uzbekistan", "Vietnam", "Burma", "Bahrain", "Belarus", "Saudi Arabia", "N. Korea"])
  .constant('CONFIG', {
    scale: 1000,
    translate: [500, 350],
    zoomContraints: [.5, 6], // min & max zoom levels
    zoomChangeSpeed: 500,
    beamSpeed: 500,
    parabolaDrawingStep: .03,
    styles: {
      // opacity
      countriesOpacity: .3,
      censoredCountriesOpacity: .45,
      censoredCountriesStrokeOpacity: .45,
      // parabolas
      parabolaLightStrokeWidth: 1,
      parabolaStrokeWidth: 1,
      // radius
      userRadiusWidth: 3.7,
      userStrokeWidth: 1.5,
      beamRadiusWidth: 3,
      nodeRadiusWidth: 2.7,
      nodeGlowRadiusWidth: 8,
      citiesRadiusWidth: .6,
      citiesGlowRadiusWidth: 2.5
    },
    sources: {
      countries: "data/countries.json",
      centroids: "data/centroids.csv"
    }
  });

function VisCtrl($scope, logFactory, modelSrvc, CONFIG, COUNTRIES_CENSORED) {
  var log = logFactory('VisCtrl'),
      model = modelSrvc.model,
      projection   = null,
      zoom         = null,
      geoPath      = null,
      ends         = [],
      parabolas    = [],
      r            = 0,
      t            = .5,
      last         = 0,
      direction    = {},
      scale        = 1,
      currentScale = null,
      svg          = null,
      layers       = {};

  function startTimer() {
    d3.timer(function(elapsed) {
       var d = elapsed - last;
        t += (elapsed - last) / CONFIG.beamSpeed;
        last = elapsed;
        loop();
    });
  }

  function loop() {
    r += .1;
    // beam animation
    var p       = Math.abs(Math.sin(t)),
        radius  = 6 + p*4/scale;
    angular.forEach(parabolas, function(parabola) {
      if (parabola.t < 1) {
        parabola.t += CONFIG.parabolaDrawingStep;
        var curve = parabola.path.data(function(d) {
          return getSlicedCurve(parabola, d);
        });
        curve.enter().append("path").attr("class", "curve");
        curve.attr("d", parabola.line);
      }
    });
    svg.select("#nodes").selectAll(".green_glow")
                        .attr("r", radius)
                        .attr("opacity", p);
  }

  function interpolate(d, p) {
    if (arguments.length < 2) p = t;
    var r = [];
    for (var i = 1; i < d.length; i++) {
      var d0 = d[i - 1],
          d1 = d[i];
      r.push({
        x: d0.x + (d1.x - d0.x) * p,
        y: d0.y + (d1.y - d0.y) * p
      });
    }
    return r;
  }

  function getLevels(parabola, d, t_) {
    if (arguments.length < 2) t_ = t;
    var x = [parabola.points.slice(0, d)];
    for (var i = 1; i < d; i++) {
      x.push(interpolate(x[x.length - 1], t_));
    }
    return x;
  }

  function getSlicedCurve(parabola, d) {
    var curve = parabola.bezier[d];
    if (!curve) {
      curve = parabola.bezier[d] = [];
      for (var t_ = 0; t_ <= 1; t_ += parabola.delta) {
        var x = getLevels(parabola, d, t_);
        curve.push(x[x.length - 1][0]);
      }
    }
    return [curve.slice(0, parabola.t / parabola.delta + 1)];
  }

  function setupProjection() {
    projection = d3.geo.mercator()
                   .scale(CONFIG.scale)
                   .translate(CONFIG.translate);
  }

  function setupZoom() {
    zoom = d3.behavior.zoom()
             .scaleExtent(CONFIG.zoomContraints)
             .on("zoom", function() { redraw(); });
  }

  function redraw() {
    //closeMenu();
    var scale     = d3.event.scale,
        translate = d3.event.translate;
    zoom.translate();
    svg.attr("transform", "translate(" + translate + ") scale(" + scale + ")");
    //updateLines(scale);
  }

  d3.timer.frame_function(function(callback) {
    setTimeout(callback, 30); // FPS à la Peter Jackson
  //setTimeout(callback, 120);
  });

  function addBlur(name, deviation) {
    svg.append("svg:defs")
       .append("svg:filter")
       .attr("id", "blur." + name)
       .append("svg:feGaussianBlur")
       .attr("stdDeviation", deviation);
  }

  function setupFilters(svg) {
    //addBlur("light",   .7);
    addBlur("medium",  .7);
    addBlur("strong", 2.5);
    addBlur("beam",    .9);
    addBlur("node",    .35);
    addBlur("green",   1.9);
    addBlur("red",     0.5);
  }

  function setupLayers() {
    layers.states     = svg.append("g").attr("id", "states");
    layers.cities     = svg.append("g").attr("id", "cities");
    layers.citiesGlow = svg.append("g").attr("id", "cities_glow");
    layers.lines      = svg.append("g").attr("id", "lines");
    layers.beams      = svg.append("g").attr("id", "beams");
    layers.nodes      = svg.append("g").attr("id", "nodes");
  }

  function loadCountries() {
    d3.json(CONFIG.sources.countries, function(collection) {
      geoPath = d3.geo.path().projection(projection);
      svg.select("#states")
         .selectAll("path")
         .data(collection.features)
         .enter().append("path")
         .attr("d", geoPath)
         .transition()
         .duration(700)
         .style("stroke", function(d) {
           if (_.contains(COUNTRIES_CENSORED, d.properties.name))
             return "#fff"; // XXX move to CONFIG
           return "none";
         })
         .style("stroke-opacity", function(d) {
           if (_.contains(COUNTRIES_CENSORED, d.properties.name))
             return CONFIG.styles.censoredCountriesStrokeOpacity;
           return 0;
         })
         .style("opacity", function(d) {
           if (_.contains(COUNTRIES_CENSORED, d.properties.name))
             return CONFIG.styles.censoredCountriesOpacity;
           return CONFIG.styles.countriesOpacity;
         })
         /* XXX ???
         .style("fill", function(d) {
           if (d.properties.name == 'China')
             return 'black';
         })
         */
         ;
    });
  }

  function addUser(lat, lon) {
    var layer = layers.nodes,
        projected = projection([lon, lat]),
        cx = projected[0],
        cy = projected[1];

    layer.append("circle")
         .attr("class", "hollow")
         .attr("r", CONFIG.styles.userRadiusWidth)
         .attr('cx', cx)
         .attr('cy', cy);
  }

  var started = false;
  $scope.$watch('model.showVis', function(val) {
    if (!val || started) return;
    log.debug('starting vis');
    started = true;
    startTimer();
    setupProjection();
    setupZoom();
    svg = d3.select("#canvas")
            .append("svg")
            .call(zoom)
            .append("g");

    setupFilters();
    setupLayers();
    loadCountries();
    addUser(model.location.lat, model.location.lon);
    updateParabolas(model.connectivity.peersCurrent, []);
  });

  function translateAlong(id, path) {
    var l = path.getTotalLength(),
        precalc = [],
        N = 512;
    for (var i = 0; i < N; ++i) {
      var p = path.getPointAtLength((i/(N-1)) * l);
      precalc.push("translate(" + p.x + "," + p.y + ")");
    }
    return function(d, i, a) {
      return function(t) {
        return direction[id] == 1 ?
          precalc[N - ((t*(N-1))|0) - 1] :
          precalc[(t*(N-1))|0];
      };
    };
  }
  function transition(circle, parabola) {
    if (!direction[parabola.id])
      direction[parabola.id] = 1;
  
    circle.transition()
          .duration(800) // XXX CONFIG
          .style("opacity", .25)
          .transition()
          .duration(1500)
          .delay(Math.round(Math.random(100) * 2500))
          .style("opacity", .25)
          .attrTween("transform", translateAlong(parabola.id, parabola.path.node()))
          .each("end", function(t) {
            // fade out the circle after it has stopped
            circle.transition()
                  .duration(500)
                  .style("opacity", 0)
                  .each("end", function() {
                    direction[parabola.id] = -direction[parabola.id]; // changes the direction
                    if (direction[parabola.id] == 1) {
                      svg.select("#" + parabola.id + "_node")
                         .transition()
                         .duration(500)
                         .style("opacity", .5)
                         .each("end", function(t) {
                           d3.select(this).transition().duration(500).style("opacity", 0);
                         });
                    } 
                    transition(circle, parabola);
                  });
          });
  }

  var counter = {next: function() { return counter.next._val++; }};
  counter.next._val = 0;

  function addParabola(peer) {
    log.debug('adding parabola for peer', peer);
    var parabola = {},
        projected1 = projection([model.location.lon, model.location.lat]),
        projected2 = projection([peer.lon, peer.lat]),
        p1 = {x: projected1[0], y: projected1[1]},
        p2 = {x: projected2[0], y: projected2[1]};

    // midpoint coordinates
    var x = Math.abs(p1.x + p2.x) / 2,
        y = Math.min(p2.y, p1.y) - Math.abs(p2.x - p1.x) * .3;

    parabola.t        = .03; // XXX magic numbers
    parabola.delta    = .03;
    parabola.points   = [{x: p1.x, y: p1.y}, {x: x, y: y}, {x: p2.x, y: p2.y}];
    parabola.line     = d3.svg.line().x(function(d) { return d.x; } ).y(function(d) { return d.y; } );
    parabola.orders   = d3.range(3, 4);
    parabola.id       = 'parabola' + counter.next();
    parabola.bezier   = [];
    parabola.c        = 'parabola_light'; // XXX

    parabola.path = svg.select("#lines")
                       .data(parabola.orders)
                       .selectAll("path.curve")
                       .data(function(d) {
                         return getSlicedCurve(parabola, d);
                       })
                       .enter()
                       .append("path")
                       .attr("class", parabola.c)
                       .attr("id", parabola.id)
                       .attr("d", parabola.line)
                       .attr("stroke-width", 1);

    // Store the parabola
    parabolas.push(parabola);

    var circle = svg.select("#beams")
                    .append("circle")
                    .attr("class", "beam")
                    .attr("filter", "url(#blur.beam)")
                    .attr("r", CONFIG.styles.beamRadiusWidth);

    transition(circle, parabola);
    //updateLines(zoom.scale() + .2);
  }

  function removeParabola(peer) {
    log.debug('removing parabola for peer', peer);
  }

  function updateParabolas(valNew, valOld) {
    var tmp = {};
    angular.forEach(valNew, function(peer) {
      var el = tmp[peer.userid] || {};
      el.value = peer;
      el.inNew = true;
      tmp[peer.userid] = el;
    });
    angular.forEach(valOld, function(peer) {
      var el = tmp[peer.userid] || {};
      el.value = peer;
      el.inOld = true;
      tmp[peer.userid] = el;
    });
    angular.forEach(tmp, function(el) {
      if (el.inOld && !el.inNew) {
        removeParabola(el.value);
      } else if (el.inNew && !el.inOld) {
        addParabola(el.value);
      } else {
        log.debug('already added parabola for current peer', el.value);
      }
    });
  }
  $scope.$watch('model.connectivity.peersCurrent', function(valNew, valOld) {
    if (!started || typeof valNew == 'undefined') return;
    if (typeof valNew != 'object') { throw 'expected array, not' + typeof valNew; } // XXX
    updateParabolas(valNew, valOld || []);
  }, true);
}
