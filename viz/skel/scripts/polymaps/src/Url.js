po.url = function(template) {
  var hosts = [],
      repeat = true;

  function format(c) {
    var max = c.zoom < 0 ? 1 : 1 << c.zoom,
        column = c.column;
    if (repeat) {
      column = c.column % max;
      if (column < 0) column += max;
    } else if ((column < 0) || (column >= max)) {
      return null;
    }
    return template.replace(/{(.)}/g, function(s, v) {
      switch (v) {
        case "S": return hosts[(Math.abs(c.zoom) + c.row + column) % hosts.length];
        case "Z": return c.zoom;
        case "X": return column;
        case "Y": return c.row;
        case "B": {
          var nw = po.map.coordinateLocation({row: c.row, column: column, zoom: c.zoom}),
              se = po.map.coordinateLocation({row: c.row + 1, column: column + 1, zoom: c.zoom}),
              pn = Math.ceil(Math.log(c.zoom) / Math.LN2);
          return se.lat.toFixed(pn)
              + "," + nw.lon.toFixed(pn)
              + "," + nw.lat.toFixed(pn)
              + "," + se.lon.toFixed(pn);
        }
      }
      return v;
    });
  }

  format.template = function(x) {
    if (!arguments.length) return template;
    template = x;
    return format;
  };

  format.hosts = function(x) {
    if (!arguments.length) return hosts;
    hosts = x;
    return format;
  };

  format.repeat = function(x) {
    if (!arguments.length) return repeat;
    repeat = x;
    return format;
  };

  return format;
};
