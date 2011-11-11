hilbert = (function() {
  // Adapted from Nick Johnson: http://bit.ly/biWkkq
  var pairs = [
    [[0, 3], [1, 0], [3, 1], [2, 0]],
    [[2, 1], [1, 1], [3, 0], [0, 2]],
    [[2, 2], [3, 3], [1, 2], [0, 1]],
    [[0, 0], [3, 2], [1, 3], [2, 3]]
  ];
  return function(x, y, z) {
    var quad = 0,
        pair,
        i = 0;
    while (--z >= 0) {
      pair = pairs[quad][(x & (1 << z) ? 2 : 0) | (y & (1 << z) ? 1 : 0)];
      i = (i << 2) | pair[0];
      quad = pair[1];
    }
    return i;
  };
})();

var po = org.polymaps;

var size = {x: 32, y: 32};

var map = po.map()
    .container(document.getElementById("map").appendChild(po.svg("svg")))
    .zoomRange([0, 6])
    .tileSize(size)
    .add(po.interact())
    .add(po.hash());

map.add(po.layer(rainbow));

map.add(po.compass()
    .pan("none"));

function rainbow(tile) {
  var rect = tile.element = po.svg("rect"),
      i = hilbert(tile.column, tile.row, tile.zoom),
      j = i / (Math.pow(4, tile.zoom) - 1),
      k = 1 << tile.zoom;
  if (tile.column < 0 || tile.column >= k) return;
  rect.setAttribute("width", size.x);
  rect.setAttribute("height", size.y);
  rect.setAttribute("fill", hsl(30, .2, j));
}

function hsl(h, s, l) {
  var m1,
      m2;

  /* Some simple corrections for h, s and l. */
  h = h % 360; if (h < 0) h += 360;
  s = s < 0 ? 0 : s > 1 ? 1 : s;
  l = l < 0 ? 0 : l > 1 ? 1 : l;

  /* From FvD 13.37, CSS Color Module Level 3 */
  m2 = l <= .5 ? l * (1 + s) : l + s - l * s;
  m1 = 2 * l - m2;

  function v(h) {
    if (h > 360) h -= 360;
    else if (h < 0) h += 360;
    if (h < 60) return m1 + (m2 - m1) * h / 60;
    if (h < 180) return m2;
    if (h < 240) return m1 + (m2 - m1) * (240 - h) / 60;
    return m1;
  }

  function vv(h) {
    return Math.round(v(h) * 255);
  }

  return "rgb(" + vv(h + 120) + "," + vv(h) + "," + vv(h - 120) + ")";
}
