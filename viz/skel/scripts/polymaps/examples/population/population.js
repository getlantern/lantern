var po = org.polymaps;

var map = po.map()
    .container(document.getElementById("map").appendChild(po.svg("svg")))
    .center({lat: 39, lon: -96})
    .zoom(4)
    .zoomRange([3, 7])
    .add(po.interact());

map.add(po.image()
    .url(po.url("http://{S}tile.cloudmade.com"
    + "/1a1b06b230af4efdbb989ea99e9841af" // http://cloudmade.com/register
    + "/20760/256/{Z}/{X}/{Y}.png")
    .hosts(["a.", "b.", "c.", ""])));

map.add(po.geoJson()
    .url("http://polymaps.appspot.com/county/{Z}/{X}/{Y}.json")
    .on("load", load)
    .id("county"));

map.add(po.geoJson()
    .url("http://polymaps.appspot.com/state/{Z}/{X}/{Y}.json")
    .id("state"));

map.add(po.compass()
    .pan("none"));

function load(e) {
  for (var i = 0; i < e.features.length; i++) {
    var feature = e.features[i];
    feature.element.setAttribute("id", feature.data.id);
  }
}
