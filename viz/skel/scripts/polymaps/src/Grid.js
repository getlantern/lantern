po.grid = function() {
  var grid = {},
      map,
      g = po.svg("g");

  g.setAttribute("class", "grid");

  function move(e) {
    var p,
        line = g.firstChild,
        size = map.size(),
        nw = map.pointLocation(zero),
        se = map.pointLocation(size),
        step = Math.pow(2, 4 - Math.round(map.zoom()));

    // Round to step.
    nw.lat = Math.floor(nw.lat / step) * step;
    nw.lon = Math.ceil(nw.lon / step) * step;

    // Longitude ticks.
    for (var x; (x = map.locationPoint(nw).x) <= size.x; nw.lon += step) {
      if (!line) line = g.appendChild(po.svg("line"));
      line.setAttribute("x1", x);
      line.setAttribute("x2", x);
      line.setAttribute("y1", 0);
      line.setAttribute("y2", size.y);
      line = line.nextSibling;
    }

    // Latitude ticks.
    for (var y; (y = map.locationPoint(nw).y) <= size.y; nw.lat -= step) {
      if (!line) line = g.appendChild(po.svg("line"));
      line.setAttribute("y1", y);
      line.setAttribute("y2", y);
      line.setAttribute("x1", 0);
      line.setAttribute("x2", size.x);
      line = line.nextSibling;
    }

    // Remove extra ticks.
    while (line) {
      var next = line.nextSibling;
      g.removeChild(line);
      line = next;
    }
  }

  grid.map = function(x) {
    if (!arguments.length) return map;
    if (map) {
      g.parentNode.removeChild(g);
      map.off("move", move).off("resize", move);
    }
    if (map = x) {
      map.on("move", move).on("resize", move);
      map.container().appendChild(g);
      map.dispatch({type: "move"});
    }
    return grid;
  };

  return grid;
};
