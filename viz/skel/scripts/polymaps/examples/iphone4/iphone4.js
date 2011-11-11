var po = org.polymaps;

// Note: po.interact has built-in touch support!
var map = po.map()
    .container(document.getElementById("map").appendChild(po.svg("svg")))
    .add(po.interact());

// Compute zoom offset for retina display.
var dz = Math.log(window.devicePixelRatio || 1) / Math.LN2;

// CloudMade image tiles, hooray!
map.add(po.image()
    .url(po.url("http://{S}tile.cloudmade.com"
    + "/1a1b06b230af4efdbb989ea99e9841af" // http://cloudmade.com/register
    + "/998/256/{Z}/{X}/{Y}.png")
    .hosts(["a.", "b.", "c.", ""]))
    .zoom(function(z) { return z + dz; }));

// no compass! pinch-to-zoom ftw
