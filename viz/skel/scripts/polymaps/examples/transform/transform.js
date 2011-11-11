var po = org.polymaps;

var transform = derive(
  // broadway & kent
  {column: 2.7943515, row: 7.5530137, zoom: 4},
  {column: 0.2945320, row: 0.3759881, zoom: 0},
  // havemeyer & north 6th
  {column: 12.818008, row: 5.0867895, zoom: 4},
  {column: 0.2945710, row: 0.3759732, zoom: 0},
  // river & north 1st
  {column: 5.3814725, row: 1.9752101, zoom: 4},
  {column: 0.2945396, row: 0.3759645, zoom: 0}
);

var map = po.map()
    .container(document.getElementById("map").appendChild(po.svg("svg")))
    .center({lon: -73.96115978350677, lat: 40.712867431331716})
    .zoomRange([15, 18])
    .zoom(15)
    .add(po.interact());

map.add(po.image()
    .url(po.url("http://{S}tile.cloudmade.com"
    + "/1a1b06b230af4efdbb989ea99e9841af" // http://cloudmade.com/register
    + "/998/256/{Z}/{X}/{Y}.png")
    .hosts(["a.", "b.", "c.", ""])));

map.add(nypl.image()
    .id("nypl")
    .scan("8021")
    .transform(transform));

map.add(po.compass()
    .pan("none"));

function key(e) {
  var nypl = document.getElementById("nypl");
  switch (e.keyCode) {
    case 49: nypl.style.opacity = e.type == "keydown" ? 1 : .5; break;
    case 50: nypl.style.opacity = e.type == "keydown" ? 0 : .5; break;
  }
}

window.addEventListener("keydown", key, false);
window.addEventListener("keyup", key, false);
