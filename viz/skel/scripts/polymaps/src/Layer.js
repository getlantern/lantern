po.layer = function(load, unload) {
  var layer = {},
      cache = layer.cache = po.cache(load, unload).size(512),
      tile = true,
      visible = true,
      zoom,
      id,
      map,
      container = po.svg("g"),
      transform,
      levelZoom,
      levels = {};

  container.setAttribute("class", "layer");
  for (var i = -4; i <= -1; i++) levels[i] = container.appendChild(po.svg("g"));
  for (var i = 2; i >= 1; i--) levels[i] = container.appendChild(po.svg("g"));
  levels[0] = container.appendChild(po.svg("g"));

  function zoomIn(z) {
    var end = levels[0].nextSibling;
    for (; levelZoom < z; levelZoom++) {
      // -4, -3, -2, -1, +2, +1, =0 // current order
      // -3, -2, -1, +2, +1, =0, -4 // insertBefore(-4, end)
      // -3, -2, -1, +1, =0, -4, +2 // insertBefore(+2, end)
      // -3, -2, -1, =0, -4, +2, +1 // insertBefore(+1, end)
      // -4, -3, -2, -1, +2, +1, =0 // relabel
      container.insertBefore(levels[-4], end);
      container.insertBefore(levels[2], end);
      container.insertBefore(levels[1], end);
      var t = levels[-4];
      for (var dz = -4; dz < 2;) levels[dz] = levels[++dz];
      levels[dz] = t;
    }
  }

  function zoomOut(z) {
    var end = levels[0].nextSibling;
    for (; levelZoom > z; levelZoom--) {
      // -4, -3, -2, -1, +2, +1, =0 // current order
      // -4, -3, -2, +2, +1, =0, -1 // insertBefore(-1, end)
      // +2, -4, -3, -2, +1, =0, -1 // insertBefore(+2, -4)
      // -4, -3, -2, -1, +2, +1, =0 // relabel
      container.insertBefore(levels[-1], end);
      container.insertBefore(levels[2], levels[-4]);
      var t = levels[2];
      for (var dz = 2; dz > -4;) levels[dz] = levels[--dz];
      levels[dz] = t;
    }
  }

  function move() {
    var map = layer.map(), // in case the layer is removed
        mapZoom = map.zoom(),
        mapZoomFraction = mapZoom - (mapZoom = Math.round(mapZoom)),
        mapSize = map.size(),
        mapAngle = map.angle(),
        tileSize = map.tileSize(),
        tileCenter = map.locationCoordinate(map.center());

    // set the layer zoom levels
    if (levelZoom != mapZoom) {
      if (levelZoom < mapZoom) zoomIn(mapZoom);
      else if (levelZoom > mapZoom) zoomOut(mapZoom);
      else levelZoom = mapZoom;
      for (var z = -4; z <= 2; z++) {
        var l = levels[z];
        l.setAttribute("class", "zoom" + (z < 0 ? "" : "+") + z + " zoom" + (mapZoom + z));
        l.setAttribute("transform", "scale(" + Math.pow(2, -z) + ")");
      }
    }

    // set the layer transform
    container.setAttribute("transform",
        "translate(" + (mapSize.x / 2) + "," + (mapSize.y / 2) + ")"
        + (mapAngle ? "rotate(" + mapAngle / Math.PI * 180 + ")" : "")
        + (mapZoomFraction ? "scale(" + Math.pow(2, mapZoomFraction) + ")" : "")
        + (transform ? transform.zoomFraction(mapZoomFraction) : ""));

    // get the coordinates of the four corners
    var c0 = map.pointCoordinate(tileCenter, zero),
        c1 = map.pointCoordinate(tileCenter, {x: mapSize.x, y: 0}),
        c2 = map.pointCoordinate(tileCenter, mapSize),
        c3 = map.pointCoordinate(tileCenter, {x: 0, y: mapSize.y});

    // round to pixel boundary to avoid anti-aliasing artifacts
    if (!mapZoomFraction && !mapAngle && !transform) {
      tileCenter.column = (Math.round(tileSize.x * tileCenter.column) + (mapSize.x & 1) / 2) / tileSize.x;
      tileCenter.row = (Math.round(tileSize.y * tileCenter.row) + (mapSize.y & 1) / 2) / tileSize.y;
    }

    // layer-specific coordinate transform
    if (transform) {
      c0 = transform.unapply(c0);
      c1 = transform.unapply(c1);
      c2 = transform.unapply(c2);
      c3 = transform.unapply(c3);
      tileCenter = transform.unapply(tileCenter);
    }

    // layer-specific zoom transform
    var tileLevel = zoom ? zoom(c0.zoom) - c0.zoom : 0;
    if (tileLevel) {
      var k = Math.pow(2, tileLevel);
      c0.column *= k; c0.row *= k;
      c1.column *= k; c1.row *= k;
      c2.column *= k; c2.row *= k;
      c3.column *= k; c3.row *= k;
      c0.zoom = c1.zoom = c2.zoom = c3.zoom += tileLevel;
    }

    // tile-specific projection
    function projection(c) {
      var zoom = c.zoom,
          max = zoom < 0 ? 1 : 1 << zoom,
          column = c.column % max,
          row = c.row;
      if (column < 0) column += max;
      return {
        locationPoint: function(l) {
          var c = po.map.locationCoordinate(l),
              k = Math.pow(2, zoom - c.zoom);
          return {
            x: tileSize.x * (k * c.column - column),
            y: tileSize.y * (k * c.row - row)
          };
        }
      };
    }

    // record which tiles are visible
    var oldLocks = cache.locks(), newLocks = {};

    // reset the proxy counts
    for (var key in oldLocks) {
      oldLocks[key].proxyCount = 0;
    }

    // load the tiles!
    if (visible && tileLevel > -5 && tileLevel < 3) {
      var ymax = c0.zoom < 0 ? 1 : 1 << c0.zoom;
      if (tile) {
        scanTriangle(c0, c1, c2, 0, ymax, scanLine);
        scanTriangle(c2, c3, c0, 0, ymax, scanLine);
      } else {
        var x = Math.floor((c0.column + c2.column) / 2),
            y = Math.max(0, Math.min(ymax - 1, Math.floor((c1.row + c3.row) / 2))),
            z = Math.min(4, c0.zoom);
        x = x >> z << z;
        y = y >> z << z;
        scanLine(x, x + 1, y);
      }
    }

    // scan-line conversion
    function scanLine(x0, x1, y) {
      var z = c0.zoom,
          z0 = 2 - tileLevel,
          z1 = 4 + tileLevel;

      for (var x = x0; x < x1; x++) {
        var t = cache.load({column: x, row: y, zoom: z}, projection);
        if (!t.ready && !(t.key in newLocks)) {
          t.proxyRefs = {};
          var c, full, proxy;

          // downsample high-resolution tiles
          for (var dz = 1; dz <= z0; dz++) {
            full = true;
            for (var dy = 0, k = 1 << dz; dy <= k; dy++) {
              for (var dx = 0; dx <= k; dx++) {
                proxy = cache.peek(c = {
                  column: (x << dz) + dx,
                  row: (y << dz) + dy,
                  zoom: z + dz
                });
                if (proxy && proxy.ready) {
                  newLocks[proxy.key] = cache.load(c);
                  proxy.proxyCount++;
                  t.proxyRefs[proxy.key] = proxy;
                } else {
                  full = false;
                }
              }
            }
            if (full) break;
          }

          // upsample low-resolution tiles
          if (!full) {
            for (var dz = 1; dz <= z1; dz++) {
              proxy = cache.peek(c = {
                column: x >> dz,
                row: y >> dz,
                zoom: z - dz
              });
              if (proxy && proxy.ready) {
                newLocks[proxy.key] = cache.load(c);
                proxy.proxyCount++;
                t.proxyRefs[proxy.key] = proxy;
                break;
              }
            }
          }
        }
        newLocks[t.key] = t;
      }
    }

    // position tiles
    for (var key in newLocks) {
      var t = newLocks[key],
          k = Math.pow(2, t.level = t.zoom - tileCenter.zoom);
      t.element.setAttribute("transform", "translate("
        + (t.x = tileSize.x * (t.column - tileCenter.column * k)) + ","
        + (t.y = tileSize.y * (t.row - tileCenter.row * k)) + ")");
    }

    // remove tiles that are no longer visible
    for (var key in oldLocks) {
      if (!(key in newLocks)) {
        var t = cache.unload(key);
        t.element.parentNode.removeChild(t.element);
        delete t.proxyRefs;
      }
    }

    // append tiles that are now visible
    for (var key in newLocks) {
      var t = newLocks[key];
      if (t.element.parentNode != levels[t.level]) {
        levels[t.level].appendChild(t.element);
        if (layer.show) layer.show(t);
      }
    }

    // flush the cache, clearing no-longer-needed tiles
    cache.flush();

    // dispatch the move event
    layer.dispatch({type: "move"});
  }

  // remove proxy tiles when tiles load
  function cleanup(e) {
    if (e.tile.proxyRefs) {
      for (var proxyKey in e.tile.proxyRefs) {
        var proxyTile = e.tile.proxyRefs[proxyKey];
        if ((--proxyTile.proxyCount <= 0) && cache.unload(proxyKey)) {
          proxyTile.element.parentNode.removeChild(proxyTile.element);
        }
      }
      delete e.tile.proxyRefs;
    }
  }

  layer.map = function(x) {
    if (!arguments.length) return map;
    if (map) {
      if (map == x) {
        container.parentNode.appendChild(container); // move to end
        return layer;
      }
      map.off("move", move).off("resize", move);
      container.parentNode.removeChild(container);
    }
    map = x;
    if (map) {
      map.container().appendChild(container);
      if (layer.init) layer.init(container);
      map.on("move", move).on("resize", move);
      move();
    }
    return layer;
  };

  layer.container = function() {
    return container;
  };

  layer.levels = function() {
    return levels;
  };

  layer.id = function(x) {
    if (!arguments.length) return id;
    id = x;
    container.setAttribute("id", x);
    return layer;
  };

  layer.visible = function(x) {
    if (!arguments.length) return visible;
    if (visible = x) container.removeAttribute("visibility")
    else container.setAttribute("visibility", "hidden");
    if (map) move();
    return layer;
  };

  layer.transform = function(x) {
    if (!arguments.length) return transform;
    transform = x;
    if (map) move();
    return layer;
  };

  layer.zoom = function(x) {
    if (!arguments.length) return zoom;
    zoom = typeof x == "function" || x == null ? x : function() { return x; };
    if (map) move();
    return layer;
  };

  layer.tile = function(x) {
    if (!arguments.length) return tile;
    tile = x;
    if (map) move();
    return layer;
  };

  layer.reload = function() {
    cache.clear();
    if (map) move();
    return layer;
  };

  layer.dispatch = po.dispatch(layer);
  layer.on("load", cleanup);

  return layer;
};

// scan-line conversion
function edge(a, b) {
  if (a.row > b.row) { var t = a; a = b; b = t; }
  return {
    x0: a.column,
    y0: a.row,
    x1: b.column,
    y1: b.row,
    dx: b.column - a.column,
    dy: b.row - a.row
  };
}

// scan-line conversion
function scanSpans(e0, e1, ymin, ymax, scanLine) {
  var y0 = Math.max(ymin, Math.floor(e1.y0)),
      y1 = Math.min(ymax, Math.ceil(e1.y1));

  // sort edges by x-coordinate
  if ((e0.x0 == e1.x0 && e0.y0 == e1.y0)
      ? (e0.x0 + e1.dy / e0.dy * e0.dx < e1.x1)
      : (e0.x1 - e1.dy / e0.dy * e0.dx < e1.x0)) {
    var t = e0; e0 = e1; e1 = t;
  }

  // scan lines!
  var m0 = e0.dx / e0.dy,
      m1 = e1.dx / e1.dy,
      d0 = e0.dx > 0, // use y + 1 to compute x0
      d1 = e1.dx < 0; // use y + 1 to compute x1
  for (var y = y0; y < y1; y++) {
    var x0 = m0 * Math.max(0, Math.min(e0.dy, y + d0 - e0.y0)) + e0.x0,
        x1 = m1 * Math.max(0, Math.min(e1.dy, y + d1 - e1.y0)) + e1.x0;
    scanLine(Math.floor(x1), Math.ceil(x0), y);
  }
}

// scan-line conversion
function scanTriangle(a, b, c, ymin, ymax, scanLine) {
  var ab = edge(a, b),
      bc = edge(b, c),
      ca = edge(c, a);

  // sort edges by y-length
  if (ab.dy > bc.dy) { var t = ab; ab = bc; bc = t; }
  if (ab.dy > ca.dy) { var t = ab; ab = ca; ca = t; }
  if (bc.dy > ca.dy) { var t = bc; bc = ca; ca = t; }

  // scan span! scan span!
  if (ab.dy) scanSpans(ca, ab, ymin, ymax, scanLine);
  if (bc.dy) scanSpans(ca, bc, ymin, ymax, scanLine);
}
