var po = org.polymaps;

var svg = n$("#map").add("svg:svg");

var map = po.map()
    .container($n(svg))
    .center({lat: 37.787, lon: -122.228})
    .zoom(12)
    .add(po.interact());

map.add(po.image()
    .url(po.url("http://{S}tile.cloudmade.com"
    + "/1a1b06b230af4efdbb989ea99e9841af" // http://cloudmade.com/register
    + "/998/256/{Z}/{X}/{Y}.png")
    .hosts(["a.", "b.", "c.", ""])));

map.add(po.geoJson()
    .features([{geometry: {coordinates: [-122.258, 37.805], type: "Point"}}])
    .on("load", load));

map.add(po.compass()
    .pan("none"));

/* Create a shadow filter. */
svg.add("svg:filter")
    .attr("id", "shadow")
    .attr("width", "140%")
    .attr("height", "140%")
  .add("svg:feGaussianBlur")
    .attr("in", "SourceAlpha")
    .attr("stdDeviation", 3);

/* Create radial gradient r1. */
svg.add("svg:radialGradient")
    .attr("id", "r1")
    .attr("fx", 0.5)
    .attr("fy", 0.9)
  .add("svg:stop")
    .attr("offset", "0%")
    .attr("stop-color", "#00bf17")
    .parent()
  .add("svg:stop")
    .attr("offset", "100%")
    .attr("stop-color", "#0f2f13");

/* Create radial gradient r2. */
svg.add("svg:radialGradient")
    .attr("id", "r2")
    .attr("fx", 0.5)
    .attr("fy", 0.1)
  .add("svg:stop")
    .attr("offset", "0%")
    .attr("stop-color", "#cccccc")
    .parent()
  .add("svg:stop")
    .attr("offset", "100%")
    .attr("stop-color", "#cccccc")
    .attr("stop-opacity", 0);

/** Post-process the GeoJSON points and replace them with shiny balls! */
function load(e) {
  var r = 20 * Math.pow(2, e.tile.zoom - 12);
  for (var i = 0; i < e.features.length; i++) {
    var c = n$(e.features[i].element),
        g = c.parent().add("svg:g", c);

    g.attr("transform", "translate(" + c.attr("cx") + "," + c.attr("cy") + ")");

    g.add("svg:circle")
        .attr("r", r)
        .attr("transform", "translate(" + r + ",0)skewX(-45)")
        .attr("opacity", .5)
        .attr("filter", "url(#shadow)");

    g.add(c
        .attr("fill", "url(#r1)")
        .attr("r", r)
        .attr("cx", null)
        .attr("cy", null));

    g.add("svg:circle")
        .attr("transform", "scale(.95,1)")
        .attr("fill", "url(#r2)")
        .attr("r", r);
  }
}
