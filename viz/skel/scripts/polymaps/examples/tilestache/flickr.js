var po = org.polymaps;

var map = po.map()
    .container(document.getElementById("map").appendChild(po.svg("svg")))
    .zoomRange([1, 10])
    .zoom(3)
    .add(po.image().url(tilestache("http://s3.amazonaws.com/info.aaronland.tiles.shapetiles/{Z}/{X}/{Y}.png")))
    .add(po.interact())
    .add(po.compass().pan("none"));

/** Returns a TileStache URL template given a string. */
function tilestache(template) {

  /** Pads the specified string to length n with character c. */
  function pad(s, n, c) {
    var m = n - s.length;
    return (m < 1) ? s : new Array(m + 1).join(c) + s;
  }

  /** Formats the specified number per TileStache. */
  function format(i) {
    var s = pad(String(i), 6, "0");
	  return s.substr(0, 3) + "/" + s.substr(3);
  }

  return function(c) {
    var max = 1 << c.zoom, column = c.column % max;
    if (column < 0) column += max;
    return template.replace(/{(.)}/g, function(s, v) {
      switch (v) {
        case "Z": return c.zoom;
        case "X": return format(column);
        case "Y": return format(c.row);
      }
      return v;
    });
  };
}
