var po = org.polymaps;

var map = po.map()
    .container(document.getElementById("map").appendChild(po.svg("svg")))
    .zoomRange([0, 5])
    .zoom(1)
    .tileSize({x: 512, y: 512})
    .center({lat: 0, lon: 0})
    .add(po.interact())
    .add(po.hash());

map.add(po.procedural()
    .zoom(function(z) { return Math.min(4, z); })
    .worker("cell-worker.js"));

map.add(po.compass()
    .pan("none"));
