var po = org.polymaps;

var map = po.map()
    .container(document.getElementById("map").appendChild(po.svg("svg")))
    .add(po.interact());

map.add(po.image()
    .url(po.url("http://{S}tile.cloudmade.com"
    + "/1a1b06b230af4efdbb989ea99e9841af" // http://cloudmade.com/register
    + "/998/256/{Z}/{X}/{Y}.png")
    .hosts(["a.", "b.", "c.", ""])));

map.add(po.geoJson()
    .url("district.json")
    .id("district")
    .on("load", load));

map.add(po.compass()
    .pan("none"));

function load(e) {
  map.extent(bounds(e.features)).zoomBy(-.5);
}

function bounds(features) {
  var i = -1,
      n = features.length,
      geometry,
      bounds = [{lon: Infinity, lat: Infinity}, {lon: -Infinity, lat: -Infinity}];
  while (++i < n) {
    geometry = features[i].data.geometry;
    boundGeometry[geometry.type](bounds, geometry.coordinates);
  }
  return bounds;
}

function boundPoint(bounds, coordinate) {
  var x = coordinate[0], y = coordinate[1];
  if (x < bounds[0].lon) bounds[0].lon = x;
  if (x > bounds[1].lon) bounds[1].lon = x;
  if (y < bounds[0].lat) bounds[0].lat = y;
  if (y > bounds[1].lat) bounds[1].lat = y;
}

function boundPoints(bounds, coordinates) {
  var i = -1, n = coordinates.length;
  while (++i < n) boundPoint(bounds, coordinates[i]);
}

function boundMultiPoints(bounds, coordinates) {
  var i = -1, n = coordinates.length;
  while (++i < n) boundPoints(bounds, coordinates[i]);
}

var boundGeometry = {
  Point: boundPoint,
  MultiPoint: boundPoints,
  LineString: boundPoints,
  MultiLineString: boundMultiPoints,
  Polygon: function(bounds, coordinates) {
    boundPoints(bounds, coordinates[0]); // exterior ring
  },
  MultiPolygon: function(bounds, coordinates) {
    var i = -1, n = coordinates.length;
    while (++i < n) boundPoints(bounds, coordinates[i][0]);
  }
};
