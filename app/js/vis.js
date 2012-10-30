'use strict';

var vis = {};

// Slow down animations
// XXX .frame_function not defined in non-minified version of d3
d3.timer.frame_function(function(callback) {
  setTimeout(callback, 30); // FPS à la Peter Jackson
});

var CONFIG = {
//scale: 500,
  scale: 1000,
//translate: [240, 300],
  translate: [500, 350],
//zoomContraints: [1, 3], // min & max zoom levels
  zoomContraints: [.5, 6], // min & max zoom levels
  zoomChangeSpeed: 500,
  beamSpeed: 500,
  layers: {},

  // http://en.wikipedia.org/wiki/Censorship_by_country
  // XXX factor out into a data source
  censoredCountries: [ "China", "Cuba", "Iran", "Myanmar", "Syria", "Turkmenistan", "Uzbekistan", "Vietnam", "Burma", "Bahrain", "Belarus", "Saudi Arabia", "N. Korea" ],

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
};

function VIS() {

  this.projection   = null;
  this.zoom         = null;

  this.geoPath      = null;

  this.centroids    = [];
  this.starts       = [];
  this.ends         = [];

  this.parabolas    = [];

  this.r            = 0;
  this.t            = .5;
  this.last         = 0;

  this.direction    = [];

  this.scale        = 1;
  this.currentScale = null;
  this.svg          = null;
}


VIS.prototype.getLevels = function(parabola, d, t_) {
  if (arguments.length < 2) t_ = t;
  var x = [parabola.points.slice(0, d)];
  for (var i = 1; i < d; i++) {
    x.push(this.interpolate(x[x.length - 1], t_));
  }
  return x;
}

VIS.prototype.getSlicedCurve = function getCurve(parabola, d) {

  var curve = parabola.bezier[d];

  if (!curve) {
    curve = parabola.bezier[d] = [];
    for (var t_ = 0; t_ <= 1; t_ += parabola.delta) {
      var x = this.getLevels(parabola, d, t_);
      curve.push(x[x.length - 1][0]);
    }
  }

  return [curve.slice(0, parabola.t / parabola.delta + 1)];
}

VIS.prototype.getCurve = function(parabola, d) {
  var curve = [];

  for (var t_ = 0; t_ <= 1; t_ += parabola.delta) {
    var x = this.getLevels(parabola, d, t_);
    curve.push(x[x.length - 1][0]);
  }

  return [curve];
}

VIS.prototype.interpolate = function(d, p) {
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


/*
 * Starts timer
 */
VIS.prototype.startTimer = function() {

  var that = this;

  d3.timer(function(elapsed) {
     var d = elapsed - that.last;

     that.t = that.t + (elapsed - that.last) / CONFIG.beamSpeed;
     that.last = elapsed;
     that.loop();

  });
}

/*
* Map projection setup
*/
VIS.prototype.setupProjection = function() {

  this.projection = d3.geo.mercator()
  .scale(CONFIG.scale)
  .translate(CONFIG.translate);

};

/*
* Zoom setup
*/
VIS.prototype.setupZoom = function() {
  var that = this;

  this.zoom = d3.behavior.zoom()
  .scaleExtent(CONFIG.zoomContraints)
  .on("zoom", function() {
    that.redraw();
  });
}

VIS.prototype.init = function() {

  this.startTimer();

  //$("#canvas").on("click", this.closeMenu);

  this.setupProjection();
  this.setupZoom();

  this.svg = d3.select("#canvas") //svg = d3.select("#canvas")
  .append("svg")
  .call(this.zoom)
  .append("g");

  this.setupFilters();
  this.setupLayers();

  this.loadCountries();
};

/**
* Generates unique ids
*/
VIS.prototype.GUID = function()
{
  var S4 = function () {
    return Math.floor(
      Math.random() * 0x10000 /* 65536 */
    ).toString(16);
  };

  return (
    "d" + S4() + S4() + "-" +
      S4() + "-" +
      S4() + "-" +
      S4() + "-" +
      S4() + S4() + S4()
  );
}

/*
* Returns a hash with the coordinates of a point
*/
VIS.prototype.getCoordinates = function(coordinates) {
  return { x: coordinates[0], y: coordinates[1] };
}

/**
* Returns a random coordinate
*/
VIS.prototype.getRandomCenter = function() {
  var i = Math.round(Math.random() * (this.centroids.length - 1));
  return this.getCoordinates(this.centroids[i]);
}

/**
* Connects the user with a random point
*/
VIS.prototype.connectUser = function() {
  var end = this.getRandomCenter();

  var parabolaID = this.drawParabola(this.userCoordinates, end, "parabola", true);
  this.addNode(end, parabolaID);
}

/*
* Connects two points with a parabola and adds a green node
*/
VIS.prototype.connectNode = function(origin) {
  var end = this.getRandomCenter();

  var parabolaID = this.drawParabola(origin, end, "parabola", true);
  this.addNode(end, parabolaID);
}

/*
* Draws n random parabolas
*/
VIS.prototype.drawParabolas = function(n) {

  var j    = 0,
      that = this;

  _.each(that.starts.slice(0, n), function(c) {
    j++;

    var origin = that.getCoordinates(c),
        end    = that.getRandomCenter();

    that.drawParabola(origin, end, "parabola_light", false);

    for (var i = 0; i <= Math.round(Math.random()*5); i++) {
      var randomPoint = that.getRandomCenter();
      that.drawParabola(end, randomPoint, "parabola_light", false);
      end = randomPoint;
    }

  });
}

/*
* Shows the position of the user
*/
VIS.prototype.addUser = function(center) {

  var layer = CONFIG.layers.nodes,
      cx    = center.x,
      cy    = center.y;

  layer
  .append("circle")
  .attr("class", "hollow")
  .attr("r", CONFIG.styles.userRadiusWidth)
  .attr('cx', cx)
  .attr('cy', cy)
}

/*
* Creates a node in the point defined by `coordinates`
*/
VIS.prototype.addNode = function(coordinates, id) {

  var layer = CONFIG.layers.nodes,
      that  = this;

  var cx = coordinates.x,
      cy = coordinates.y;

  // Green glow
  layer.append("circle")
  .attr("class", "green_glow_2")
  .attr('cx', cx)
  .attr('cy', cy)
  .attr("id", id + "_node")
  .attr("filter", "url(#blur.green)")
  .style("opacity", 0);

  // Green glow
  layer.append("circle")
  .attr("class", "green_glow")
  .attr("r", CONFIG.styles.nodeGlowRadiusWidth)
  .attr('cx', cx)
  .attr('cy', cy)
  .attr("filter", "url(#blur.green)")

  // Green dot
  layer.append("circle")
  .attr("r", CONFIG.styles.nodeRadiusWidth)
  .attr("class", "dot_green")
  .style("opacity", 0)
  .attr('cx', cx)
  .attr('cy', cy)
  //.attr("id", id + "_node")
  .attr("filter", "url(#blur.node)")
  .on("click", function() {
    d3.event.stopPropagation();

    // Coordinates of the click adjusted to the zoom
    // level & translation vector

    var t = that.zoom.translate(),
        x = (that.zoom.scale() * cx) + t[0],
        y = (that.zoom.scale() * cy) + t[1];

    //that.openMenu(x, y);
  })
  .transition()
  .duration(500)
  .style("opacity", 1)

  this.updateLines(that.zoom.scale() + .2);
}


$.fn.rotate = function(deg) {
  $(this).css("transform", "rotate(" + deg + "deg)");
  $(this).find("i").css("transform", "rotate(" + -1 * deg + "deg)");
  $(this).css("-ms-transform", "rotate(" + deg + "deg)");
  $(this).find("i").css("-ms-transform", "rotate(" + -1 * deg + "deg)");
  $(this).css("-webkit-transform", "rotate(" + deg + "deg)");
  $(this).find("i").css("-webkit-transform", "rotate(" + -1 * deg + "deg)");
  $(this).css("-moz-transform", "rotate(" + deg + "deg)");
  $(this).find("i").css("-moz-transform", "rotate(" + -1 * deg + "deg)");
  $(this).css("-o-transform", "rotate(" + deg + "deg)");
  $(this).find("i").css("-o-transform", "rotate(" + -1 * deg + "deg)");
}


/*
* Keeps the aspect of the lines & points consistent in every zoom level
*/
VIS.prototype.updateLines = function(scale) {

  this.svg.select("#nodes")
  .selectAll(".hollow")
  .attr("r", CONFIG.styles.userRadiusWidth/scale)
  .style("stroke-width", CONFIG.styles.userStrokeWidth/scale)

  this.svg.select("#beams")
  .selectAll("circle")
  .attr("r", CONFIG.styles.beamRadiusWidth/scale)

  this.svg.select("#cities")
  .selectAll(".dot")
  .attr("r", CONFIG.styles.citiesRadiusWidth/scale)

  this.svg.select("#cities_glow")
  .selectAll(".glow")
  .attr("r", CONFIG.styles.citiesGlowRadiusWidth/scale)

  this.svg.select("#nodes")
  .selectAll(".green_glow_2")
  .attr("r", CONFIG.styles.nodeGlowRadiusWidth/scale)

  this.svg.select("#nodes")
  .selectAll(".green_glow")
  .attr("r", CONFIG.styles.nodeGlowRadiusWidth/scale)

  this.svg.select("#nodes")
  .selectAll(".dot_green")
  .attr("r", CONFIG.styles.nodeRadiusWidth/scale)

  this.svg.select("#lines")
  .selectAll(".parabola_light")
  .attr("stroke-width", CONFIG.styles.parabolaLightStrokeWidth  / scale)

  this.svg.select("#lines")
  .selectAll(".parabola")
  .attr("stroke-width", CONFIG.styles.parabolaStrokeWidth / scale);
}

VIS.prototype.zoomIn = function(that) {

  var scale = that.zoom.scale(),
      t     = that.zoom.translate();

  if (scale > 2) return;

  that.zoom.scale(scale + 1);

  var x = -250 * (that.zoom.scale() - 1),
      y = -250 * (that.zoom.scale() - 1);

  that.zoom.translate([x, y]);

  this.svg
  .transition()
  .duration(CONFIG.zoomChangeSpeed)
  .attr("transform", "translate(" + x + "," + y + ") scale(" + that.zoom.scale() + ")");

  that.updateLines(that.zoom.scale() + .2);
}

VIS.prototype.zoomOut = function(that) {
  var scale = that.zoom.scale(),
      t     = that.zoom.translate();

  if (scale < 1.5) return;

  that.zoom.scale(scale - 1);

  var x = -250 * (that.zoom.scale() - 1),
      y = -250 * (that.zoom.scale() - 1);

  that.zoom.translate([x, y]);

  this.svg
  .transition()
  .duration(CONFIG.zoomChangeSpeed)
  .attr("transform", "translate(" + x + "," + y + ") scale(" + that.zoom.scale() + ")");

  that.updateLines(that.zoom.scale() + .2);
}

VIS.prototype.translateAlong = function(id, path) {

  var that    = this,
      l       = path.getTotalLength(),
      precalc = [];

   if (precalc.length == 0) {

    var N = 512;

    for(var i = 0; i < N; ++i) {

      var p = path.getPointAtLength((i/(N-1)) * l);
      precalc.push("translate(" + p.x + "," + p.y + ")");

    }
  }

  return function(d, i, a) {
    return function(t) {

      var p = null;

      if (that.direction[id] == 1) p = precalc[N - ((t*(N-1))>>0) - 1]; //path.getPointAtLength((1 - t) * l);
      else p = precalc[(t*(N-1))>>0];

      return p;
    };
  };
}

VIS.prototype.transition = function(circle, parabola) {

  var that = this;


  if (!this.direction[parabola.id]) this.direction[parabola.id] = 1;

  circle
  .transition()
  .duration(800)
  .style("opacity", .25)
  .transition()
  .duration(1500)
  .delay(Math.round(Math.random(100) * 2500))
  .style("opacity", .25)
  .attrTween("transform", this.translateAlong(parabola.id, parabola.path.node()))
  .each("end", function(t) {

    // Fade out the circle after it has stopped

    circle
    .transition()
    .duration(500)
    .style("opacity", 0)
    .each("end", function() {

      that.direction[parabola.id] = -1*that.direction[parabola.id]; // changes the direction

      if (that.direction[parabola.id] == 1) {
        that.svg.select("#" + parabola.id + "_node")
        .transition()
        .duration(500)
        .style("opacity", .5)
        .each("end", function(t) {

          d3.select(this).transition()
          .duration(500)
          .style("opacity", 0);

        });
      }

      that.transition(circle, parabola);
    });
  });
}

VIS.prototype.drawParabola = function(p1, p2, c, animated) {

  var parabola = {};

  // middle point coordinates
  var x = Math.abs(p1.x + p2.x) / 2,
      y = Math.min(p2.y, p1.y) - Math.abs(p2.x - p1.x) * .3;

  var that   = this;

  parabola.animated = animated;
  parabola.t        = .03;
  parabola.delta    = .03;
  parabola.points   = [ { x: p1.x, y: p1.y}, { x: x, y: y }, { x: p2.x, y: p2.y} ];
  parabola.line     = d3.svg.line().x(function(d) { return d.x; } ).y(function(d) { return d.y; } );
  parabola.orders   = d3.range(3, 4);
  parabola.id       = this.GUID();
  parabola.bezier   = [];
  parabola.c        = c;

  parabola.path = this.svg
  .select("#lines")
  .data(parabola.orders)
  .selectAll("path.curve")
  .data(function(d) {

    if (animated) {
      return that.getSlicedCurve(parabola, d);
    } else {
      return that.getCurve(parabola, d);
    }

  })
  .enter()
  .append("path")
  .attr("class", parabola.c)
  .attr("id", parabola.id)
  .attr("d", parabola.line)
  .attr("stroke-width", 1)

  // Store the parabola
  this.parabolas.push(parabola);

  if (animated) {
    var circle = this.svg
    .select("#beams")
    .append("circle")
    .attr("class", "beam")
    .attr("filter", "url(#blur.beam)")
    .attr("r", CONFIG.styles.beamRadiusWidth);

    that.transition(circle, parabola);
  }

  this.updateLines(that.zoom.scale() + .2);
  return parabola.id
}

/*
* This method is called every time the user
* zooms or pans.
*/
VIS.prototype.redraw = function() {

  //this.closeMenu();

  var scale     = d3.event.scale,
      translate = d3.event.translate;

  var t     = this.zoom.translate();

  this.svg
  .attr("transform", "translate(" + translate + ") scale(" + scale + ")");

  this.updateLines(scale);
}

/*
* Defines a blur effect
*/
VIS.prototype.addBlur = function(name, deviation) {
  this.svg
  .append("svg:defs")
  .append("svg:filter")
  .attr("id", "blur." + name)
  .append("svg:feGaussianBlur")
  .attr("stdDeviation", deviation);
}

/*
* Defines several filters
*/
VIS.prototype.setupFilters = function(svg) {
  //this.addBlur("light",   .7);
  this.addBlur("medium",  .7);
  this.addBlur("strong", 2.5);
  this.addBlur("beam",    .9);
  this.addBlur("node",    .35);
  this.addBlur("green",   1.9);
  this.addBlur("red",     0.5);
}

/*
* Main loop
*/
VIS.prototype.loop = function() {
  var that = this;

  this.r = this.r + .1;

  // Beam animation

  var p       = Math.abs(Math.sin(this.t)),
      radius  = 6 + p*4/this.scale;


  _.each(this.parabolas, function(parabola) {

    if (parabola.animated && parabola.t < 1) {

      parabola.t += CONFIG.parabolaDrawingStep;

      var curve = parabola.path
      .data(function(d) {
        return that.getSlicedCurve(parabola, d);
      })

      curve.enter()
      .append("path")
      .attr("class", "curve");
      curve.attr("d", parabola.line);
    }

  });

  this.svg.select("#nodes")
  .selectAll(".green_glow")
  .attr("r", radius)
  .attr("opacity", p);

}

VIS.prototype.setupLayers = function() {

  CONFIG.layers.states     = this.svg.append("g").attr("id", "states");
  CONFIG.layers.cities     = this.svg.append("g").attr("id", "cities");
  CONFIG.layers.citiesGlow = this.svg.append("g").attr("id", "cities_glow");
  CONFIG.layers.lines      = this.svg.append("g").attr("id", "lines");
  CONFIG.layers.beams      = this.svg.append("g").attr("id", "beams");
  CONFIG.layers.nodes      = this.svg.append("g").attr("id", "nodes");

}

VIS.prototype.loadCountries = function() {
  var that = this;

  d3.json(CONFIG.sources.countries, function(collection) {

    that.geoPath = d3.geo.path().projection(that.projection)

    that.svg.select("#states")
    .selectAll("path")
    .data(collection.features)
    .enter().append("path")
    .attr("d", that.geoPath)
    .transition()
    .duration(700)
    .style("stroke", function(d) {

      if (_.include(CONFIG.censoredCountries, d.properties.name)) return "#fff";
      else return "none";

    })
    .style("stroke-opacity", function(d) {

      if (_.include(CONFIG.censoredCountries, d.properties.name)) return CONFIG.styles.censoredCountriesStrokeOpacity;
      else return 0;

    })
    .style("opacity", function(d) {

      if (_.include(CONFIG.censoredCountries, d.properties.name)) return CONFIG.styles.censoredCountriesOpacity;
      else return CONFIG.styles.countriesOpacity;

    })
    .style("fill", function(d) {

      if (d.properties.name == 'China') return 'black';

    })

    that.loadCentroids();

  });
}

VIS.prototype.loadCentroids = function() {

  var that = this;

  d3.csv(CONFIG.sources.centroids, function(collection) {

    that.svg.select("#cities_glow")
    .selectAll("circle")
    .data(collection)
    .enter()
    .append("circle")
    //.attr("filter", "url(#blur.light)")
    .attr("class", "glow")
    .attr('cx', function(d) { return that.projection([d.LONG, d.LAT])[0]; } )
    .attr('cy', function(d) { return that.projection([d.LONG, d.LAT])[1]; } )
    .attr("r", CONFIG.styles.citiesGlowRadiusWidth);

    that.svg.select("#cities")
    .selectAll("circle")
    .data(collection)
    .enter()
    .append("circle")
    .attr("class", "dot")
    .attr('cx', function(d, i) {

      var p = Math.round(Math.random()*10);
      var coordinates = that.projection([d.LONG, d.LAT]);

      that.centroids.push(coordinates);

      if (p == 1) {
        that.starts.push(coordinates);
      } else if (p == 0) {
        that.ends.push(coordinates);
      }

      return coordinates[0];

    })
    .attr('cy', function(d, i) { return that.projection([d.LONG, d.LAT])[1]; })
    .attr("r", CONFIG.styles.citiesRadiusWidth);

    // Draw some random parabolas
    that.drawParabolas(3);

    // Draw the user's circle and connect it
    var center = that.getRandomCenter();

    that.userCoordinates = center;

    that.addUser(center);

    for (var i = 0; i<= 2 + Math.round(Math.random() * 3); i++) {
      that.connectUser();
    }
  });
}

function startVis() {
  vis = new VIS();

  // zoom bindings
  $(".zoom_in").on("click",  function() { vis.zoomIn(vis); });
  $(".zoom_out").on("click", function() { vis.zoomOut(vis); });

  vis.init();
}
