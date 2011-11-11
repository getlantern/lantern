var po = org.polymaps;

var map = po.map()
    .container(document.getElementById("map").appendChild(po.svg("svg")))
    .zoomRange([12, 15])
    .add(po.interact());

map.add(po.image()
    .url(po.url("http://{S}tile.cloudmade.com"
    + "/1a1b06b230af4efdbb989ea99e9841af" // http://cloudmade.com/register
    + "/998/256/{Z}/{X}/{Y}.png")
    .hosts(["a.", "b.", "c.", ""])));

map.add(po.layer(overlay)
    .tile(false));

map.add(po.compass()
    .pan("none"));

/** A lightweight layer implementation for an image overlay. */
function overlay(tile, proj) {
  proj = proj(tile);
  var tl = proj.locationPoint({lon: -122.518, lat: 37.816}),
      br = proj.locationPoint({lon: -122.375, lat: 37.755}),
      image = tile.element = po.svg("image");
  image.setAttribute("preserveAspectRatio", "none");
  image.setAttribute("x", tl.x);
  image.setAttribute("y", tl.y);
  image.setAttribute("width", br.x - tl.x);
  image.setAttribute("height", br.y - tl.y);
  image.setAttributeNS("http://www.w3.org/1999/xlink", "href", "sf1906.png");
}
