var po = org.polymaps;

var map = po.map()
    .container(document.getElementById("map").appendChild(po.svg("svg")))
    .zoomRange([0, 20])
    .zoom(1)
    .center({lat: 0, lon: 0})
    .add(po.interact())
    .add(po.hash());

map.add(po.procedural()
    .worker("mandelbrot-worker.js"));

map.add(po.compass()
    .pan("none"));
