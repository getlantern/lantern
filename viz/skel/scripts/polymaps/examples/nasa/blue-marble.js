var po = org.polymaps;

var map = po.map()
    .container(document.getElementById("map").appendChild(po.svg("svg")))
    .zoomRange([0, 9])
    .zoom(7)
    .add(po.image().url("http://s3.amazonaws.com/com.modestmaps.bluemarble/{Z}-r{Y}-c{X}.jpg"))
    .add(po.interact())
    .add(po.compass().pan("none"));
