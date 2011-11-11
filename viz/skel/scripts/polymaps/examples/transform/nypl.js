var nypl = {};

nypl.image = function() {
  var image = po.layer(load, unload),
      scanInfo,
      scanId,
      tiles = {};

  var infoTemplate = "http://maps.nypl.org/warper-dev/maps/{I}.json"
      + "?callback=nypl.image.$callback{I}";

  var imageTemplate = "http://dev.maps.nypl.org/warper/mapscans/wms/{I}"
      + "?FORMAT=image%2Fjpeg"
      + "&STATUS=unwarped"
      + "&SERVICE=WMS"
      + "&VERSION=1.1.1"
      + "&REQUEST=GetMap"
      + "&STYLES="
      + "&EXCEPTIONS=application%2Fvnd.ogc.se_inimage"
      + "&SRS=EPSG%3A4326"
      + "&WIDTH={W}"
      + "&HEIGHT={H}"
      + "&BBOX={B}";

  function load(tile) {
    var element = tile.element = po.svg("image");
    if (scanInfo) request(tile);
    tiles[tile.key] = tile;
  }

  function request(tile) {
    var element = tile.element,
        size = image.map().tileSize(),
        w = size.x,
        h = size.y,
        k = Math.pow(2, -tile.zoom) * Math.max(scanInfo.width, scanInfo.height),
        x = ~~(tile.column * k),
        y = scanInfo.height - ~~(tile.row * k),
        z = ~~k,
        dx = z,
        dy = z;

    if (y < dy) {
      dy = y;
      h = ~~(size.y * dy / z);
    }

    if (x > scanInfo.width - dx) {
      dx = scanInfo.width - x;
      w = ~~(size.x * dx / z);
    }

    element.setAttribute("opacity", 0);
    if ((x < 0) || (dx <= 0) || (dy <= 0)) return; // nothing to display
    element.setAttribute("width", w);
    element.setAttribute("height", h);

    var url = imageTemplate.replace(/{(.)}/g, function(s, v) {
      switch (v) {
        case "I": return scanId;
        case "W": return w;
        case "H": return h;
        case "B": return [x, y - dy, x + dx, y].join(",");
      }
      return v;
    });

    tile.request = po.queue.image(element, url, function() {
      delete tile.request;
      tile.ready = true;
      element.removeAttribute("opacity");
      image.dispatch({type: "load", tile: tile});
    });
  }

  function unload(tile) {
    if (tile.request) tile.request.abort(true);
    delete tiles[tiles.key];
  }

  image.scan = function(x) {
    if (!arguments.length) return scanId;
    scanId = x;
    // JSONP, since nypl.org doesn't Access-Control-Allow-Origin: *
    nypl.image["$callback" + x] = function(x) {
      self.scanInfo = scanInfo = x.items[0];
      for (var key in tiles) request(tiles[key]);
    };
    var script = document.createElement("script");
    script.setAttribute("type", "text/javascript");
    script.setAttribute("src", infoTemplate.replace(/{I}/g, x));
    document.body.appendChild(script);
    return image;
  }

  return image;
};

function derive(a0, a1, b0, b1, c0, c1) {

  function solve(r1, s1, t1, r2, s2, t2, r3, s3, t3) {
    var a = (((t2 - t3) * (s1 - s2)) - ((t1 - t2) * (s2 - s3)))
          / (((r2 - r3) * (s1 - s2)) - ((r1 - r2) * (s2 - s3))),
        b = (((t2 - t3) * (r1 - r2)) - ((t1 - t2) * (r2 - r3)))
          / (((s2 - s3) * (r1 - r2)) - ((s1 - s2) * (r2 - r3)));
        c = t1 - (r1 * a) - (s1 * b);
    return [a, b, c];
  }

  function normalize(c) {
    var k = Math.pow(2, -c.zoom);
    return {
      x: c.column * k,
      y: c.row * k
    };
  }

  a0 = normalize(a0);
  a1 = normalize(a1);
  b0 = normalize(b0);
  b1 = normalize(b1);
  c0 = normalize(c0);
  c1 = normalize(c1);

  var x = solve(a0.x, a0.y, a1.x,
                b0.x, b0.y, b1.x,
                c0.x, c0.y, c1.x),
      y = solve(a0.x, a0.y, a1.y,
                b0.x, b0.y, b1.y,
                c0.x, c0.y, c1.y);

  return po.transform(x[0], y[0], x[1], y[1], x[2], y[2]);
}
