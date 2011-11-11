var po = org.polymaps;

var color = pv.Scale.linear()
    .domain(0, 50, 70, 100)
    .range("#F00", "#930", "#FC0", "#3B0");

var map = po.map()
    .container(document.getElementById("map").appendChild(po.svg("svg")))
    .center({lat: 37.76, lon: -122.44})
    .zoom(13)
    .zoomRange([12, 16])
    .add(po.interact());

map.add(po.image()
    .url(po.url("http://{S}tile.cloudmade.com"
    + "/1a1b06b230af4efdbb989ea99e9841af" // http://cloudmade.com/register
    + "/999/256/{Z}/{X}/{Y}.png")
    .hosts(["a.", "b.", "c.", ""])));

map.add(po.geoJson()
    .url("streets.json")
    .id("streets")
    .zoom(12)
    .tile(false)
  .on("load", po.stylist()
    .attr("stroke", function(d) { return color(d.properties.PCI).color; })
    .title(function(d) { return d.properties.STREET + ": " + d.properties.PCI + " PCI"; })));

map.add(po.compass()
    .pan("none"));
