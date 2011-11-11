po.map = function() {
  var map = {},
      container,
      size,
      sizeActual = zero,
      sizeRadius = zero, // sizeActual / 2
      tileSize = {x: 256, y: 256},
      center = {lat: 37.76487, lon: -122.41948},
      zoom = 12,
      zoomFraction = 0,
      zoomFactor = 1, // Math.pow(2, zoomFraction)
      zoomRange = [1, 18],
      angle = 0,
      angleCos = 1, // Math.cos(angle)
      angleSin = 0, // Math.sin(angle)
      angleCosi = 1, // Math.cos(-angle)
      angleSini = 0, // Math.sin(-angle)
      ymin = -180, // lat2y(centerRange[0].lat)
      ymax = 180; // lat2y(centerRange[1].lat)

  var centerRange = [
    {lat: y2lat(ymin), lon: -Infinity},
    {lat: y2lat(ymax), lon: Infinity}
  ];

  map.locationCoordinate = function(l) {
    var c = po.map.locationCoordinate(l),
        k = Math.pow(2, zoom);
    c.column *= k;
    c.row *= k;
    c.zoom += zoom;
    return c;
  };

  map.coordinateLocation = po.map.coordinateLocation;

  map.coordinatePoint = function(tileCenter, c) {
    var kc = Math.pow(2, zoom - c.zoom),
        kt = Math.pow(2, zoom - tileCenter.zoom),
        dx = (c.column * kc - tileCenter.column * kt) * tileSize.x * zoomFactor,
        dy = (c.row * kc - tileCenter.row * kt) * tileSize.y * zoomFactor;
    return {
      x: sizeRadius.x + angleCos * dx - angleSin * dy,
      y: sizeRadius.y + angleSin * dx + angleCos * dy
    };
  };

  map.pointCoordinate = function(tileCenter, p) {
    var kt = Math.pow(2, zoom - tileCenter.zoom),
        dx = (p.x - sizeRadius.x) / zoomFactor,
        dy = (p.y - sizeRadius.y) / zoomFactor;
    return {
      column: tileCenter.column * kt + (angleCosi * dx - angleSini * dy) / tileSize.x,
      row: tileCenter.row * kt + (angleSini * dx + angleCosi * dy) / tileSize.y,
      zoom: zoom
    };
  };

  map.locationPoint = function(l) {
    var k = Math.pow(2, zoom + zoomFraction - 3) / 45,
        dx = (l.lon - center.lon) * k * tileSize.x,
        dy = (lat2y(center.lat) - lat2y(l.lat)) * k * tileSize.y;
    return {
      x: sizeRadius.x + angleCos * dx - angleSin * dy,
      y: sizeRadius.y + angleSin * dx + angleCos * dy
    };
  };

  map.pointLocation = function(p) {
    var k = 45 / Math.pow(2, zoom + zoomFraction - 3),
        dx = (p.x - sizeRadius.x) * k,
        dy = (p.y - sizeRadius.y) * k;
    return {
      lon: center.lon + (angleCosi * dx - angleSini * dy) / tileSize.x,
      lat: y2lat(lat2y(center.lat) - (angleSini * dx + angleCosi * dy) / tileSize.y)
    };
  };

  function rezoom() {
    if (zoomRange) {
      if (zoom < zoomRange[0]) zoom = zoomRange[0];
      else if (zoom > zoomRange[1]) zoom = zoomRange[1];
    }
    zoomFraction = zoom - (zoom = Math.round(zoom));
    zoomFactor = Math.pow(2, zoomFraction);
  }

  function recenter() {
    if (!centerRange) return;
    var k = 45 / Math.pow(2, zoom + zoomFraction - 3);

    // constrain latitude
    var y = Math.max(Math.abs(angleSin * sizeRadius.x + angleCos * sizeRadius.y),
                     Math.abs(angleSini * sizeRadius.x + angleCosi * sizeRadius.y)),
        lat0 = y2lat(ymin - y * k / tileSize.y),
        lat1 = y2lat(ymax + y * k / tileSize.y);
    center.lat = Math.max(lat0, Math.min(lat1, center.lat));

    // constrain longitude
    var x = Math.max(Math.abs(angleSin * sizeRadius.y + angleCos * sizeRadius.x),
                     Math.abs(angleSini * sizeRadius.y + angleCosi * sizeRadius.x)),
        lon0 = centerRange[0].lon - x * k / tileSize.x,
        lon1 = centerRange[1].lon + x * k / tileSize.x;
    center.lon = Math.max(lon0, Math.min(lon1, center.lon));
 }

  // a place to capture mouse events if no tiles exist
  var rect = po.svg("rect");
  rect.setAttribute("visibility", "hidden");
  rect.setAttribute("pointer-events", "all");

  map.container = function(x) {
    if (!arguments.length) return container;
    container = x;
    container.setAttribute("class", "map");
    container.appendChild(rect);
    return map.resize(); // infer size
  };

  map.focusableParent = function() {
    for (var p = container; p; p = p.parentNode) {
      if (p.tabIndex >= 0) return p;
    }
    return window;
  };

  map.mouse = function(e) {
    var point = (container.ownerSVGElement || container).createSVGPoint();
    if ((bug44083 < 0) && (window.scrollX || window.scrollY)) {
      var svg = document.body.appendChild(po.svg("svg"));
      svg.style.position = "absolute";
      svg.style.top = svg.style.left = "0px";
      var ctm = svg.getScreenCTM();
      bug44083 = !(ctm.f || ctm.e);
      document.body.removeChild(svg);
    }
    if (bug44083) {
      point.x = e.pageX;
      point.y = e.pageY;
    } else {
      point.x = e.clientX;
      point.y = e.clientY;
    }
    return point.matrixTransform(container.getScreenCTM().inverse());
  };

  map.size = function(x) {
    if (!arguments.length) return sizeActual;
    size = x;
    return map.resize(); // size tiles
  };

  map.resize = function() {
    if (!size) {
      rect.setAttribute("width", "100%");
      rect.setAttribute("height", "100%");
      b = rect.getBBox();
      sizeActual = {x: b.width, y: b.height};
      resizer.add(map);
    } else {
      sizeActual = size;
      resizer.remove(map);
    }
    rect.setAttribute("width", sizeActual.x);
    rect.setAttribute("height", sizeActual.y);
    sizeRadius = {x: sizeActual.x / 2, y: sizeActual.y / 2};
    recenter();
    map.dispatch({type: "resize"});
    return map;
  };

  map.tileSize = function(x) {
    if (!arguments.length) return tileSize;
    tileSize = x;
    map.dispatch({type: "move"});
    return map;
  };

  map.center = function(x) {
    if (!arguments.length) return center;
    center = x;
    recenter();
    map.dispatch({type: "move"});
    return map;
  };

  map.panBy = function(x) {
    var k = 45 / Math.pow(2, zoom + zoomFraction - 3),
        dx = x.x * k,
        dy = x.y * k;
    return map.center({
      lon: center.lon + (angleSini * dy - angleCosi * dx) / tileSize.x,
      lat: y2lat(lat2y(center.lat) + (angleSini * dx + angleCosi * dy) / tileSize.y)
    });
  };

  map.centerRange = function(x) {
    if (!arguments.length) return centerRange;
    centerRange = x;
    if (centerRange) {
      ymin = centerRange[0].lat > -90 ? lat2y(centerRange[0].lat) : -Infinity;
      ymax = centerRange[0].lat < 90 ? lat2y(centerRange[1].lat) : Infinity;
    } else {
      ymin = -Infinity;
      ymax = Infinity;
    }
    recenter();
    map.dispatch({type: "move"});
    return map;
  };

  map.zoom = function(x) {
    if (!arguments.length) return zoom + zoomFraction;
    zoom = x;
    rezoom();
    return map.center(center);
  };

  map.zoomBy = function(z, x0, l) {
    if (arguments.length < 2) return map.zoom(zoom + zoomFraction + z);

    // compute the location of x0
    if (arguments.length < 3) l = map.pointLocation(x0);

    // update the zoom level
    zoom = zoom + zoomFraction + z;
    rezoom();

    // compute the new point of the location
    var x1 = map.locationPoint(l);

    return map.panBy({x: x0.x - x1.x, y: x0.y - x1.y});
  };

  map.zoomRange = function(x) {
    if (!arguments.length) return zoomRange;
    zoomRange = x;
    return map.zoom(zoom + zoomFraction);
  };

  map.extent = function(x) {
    if (!arguments.length) return [
      map.pointLocation({x: 0, y: sizeActual.y}),
      map.pointLocation({x: sizeActual.x, y: 0})
    ];

    // compute the extent in points, scale factor, and center
    var bl = map.locationPoint(x[0]),
        tr = map.locationPoint(x[1]),
        k = Math.max((tr.x - bl.x) / sizeActual.x, (bl.y - tr.y) / sizeActual.y),
        l = map.pointLocation({x: (bl.x + tr.x) / 2, y: (bl.y + tr.y) / 2});

    // update the zoom level
    zoom = zoom + zoomFraction - Math.log(k) / Math.LN2;
    rezoom();

    // set the new center
    return map.center(l);
  };

  map.angle = function(x) {
    if (!arguments.length) return angle;
    angle = x;
    angleCos = Math.cos(angle);
    angleSin = Math.sin(angle);
    angleCosi = Math.cos(-angle);
    angleSini = Math.sin(-angle);
    recenter();
    map.dispatch({type: "move"});
    return map;
  };

  map.add = function(x) {
    x.map(map);
    return map;
  };

  map.remove = function(x) {
    x.map(null);
    return map;
  };

  map.dispatch = po.dispatch(map);

  return map;
};

function resizer(e) {
  for (var i = 0; i < resizer.maps.length; i++) {
    resizer.maps[i].resize();
  }
}

resizer.maps = [];

resizer.add = function(map) {
  for (var i = 0; i < resizer.maps.length; i++) {
    if (resizer.maps[i] == map) return;
  }
  resizer.maps.push(map);
};

resizer.remove = function(map) {
  for (var i = 0; i < resizer.maps.length; i++) {
    if (resizer.maps[i] == map) {
      resizer.maps.splice(i, 1);
      return;
    }
  }
};

// Note: assumes single window (no frames, iframes, etc.)!
if (window.addEventListener) {
  window.addEventListener("resize", resizer, false);
  window.addEventListener("load", resizer, false);
}

// See http://wiki.openstreetmap.org/wiki/Mercator

function y2lat(y) {
  return 360 / Math.PI * Math.atan(Math.exp(y * Math.PI / 180)) - 90;
}

function lat2y(lat) {
  return 180 / Math.PI * Math.log(Math.tan(Math.PI / 4 + lat * Math.PI / 360));
}

po.map.locationCoordinate = function(l) {
  var k = 1 / 360;
  return {
    column: (l.lon + 180) * k,
    row: (180 - lat2y(l.lat)) * k,
    zoom: 0
  };
};

po.map.coordinateLocation = function(c) {
  var k = 45 / Math.pow(2, c.zoom - 3);
  return {
    lon: k * c.column - 180,
    lat: y2lat(180 - k * c.row)
  };
};

// https://bugs.webkit.org/show_bug.cgi?id=44083
var bug44083 = /WebKit/.test(navigator.userAgent) ? -1 : 0;
