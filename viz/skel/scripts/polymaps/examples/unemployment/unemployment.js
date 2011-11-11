var po = org.polymaps;

// Compute noniles.
var quantile = pv.Scale.quantile()
    .quantiles(9)
    .domain(pv.values(unemployment))
    .range(0, 8);

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
    if (feature.data.id.substring(9) == "000") continue; // skip bogus counties
    var d = unemployment[feature.data.id.substring(7)];
    feature.element.setAttribute("class", "q" + quantile(d) + "-" + 9);
    feature.element.appendChild(po.svg("title").appendChild(
        document.createTextNode(feature.data.properties.name + ": " + d + "%"))
        .parentNode);
  }
}

map.container().setAttribute("class", "Blues");
