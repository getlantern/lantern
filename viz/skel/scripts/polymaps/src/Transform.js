po.transform = function(a, b, c, d, e, f) {
  var transform = {},
      zoomDelta,
      zoomFraction,
      k;

  if (!arguments.length) {
    a = 1; c = 0; e = 0;
    b = 0; d = 1; f = 0;
  }

  transform.zoomFraction = function(x) {
    if (!arguments.length) return zoomFraction;
    zoomFraction = x;
    zoomDelta = Math.floor(zoomFraction + Math.log(Math.sqrt(a * a + b * b + c * c + d * d)) / Math.LN2);
    k = Math.pow(2, -zoomDelta);
    return transform;
  };

  transform.apply = function(x) {
    var k0 = Math.pow(2, -x.zoom),
        k1 = Math.pow(2, x.zoom - zoomDelta);
    return {
      column: (a * x.column * k0 + c * x.row * k0 + e) * k1,
      row: (b * x.column * k0 + d * x.row * k0 + f) * k1,
      zoom: x.zoom - zoomDelta
    };
  };

  transform.unapply = function(x) {
    var k0 = Math.pow(2, -x.zoom),
        k1 = Math.pow(2, x.zoom + zoomDelta);
    return {
      column: (x.column * k0 * d - x.row * k0 * c - e * d + f * c) / (a * d - b * c) * k1,
      row: (x.column * k0 * b - x.row * k0 * a - e * b + f * a) / (c * b - d * a) * k1,
      zoom: x.zoom + zoomDelta
    };
  };

  transform.toString = function() {
    return "matrix(" + [a * k, b * k, c * k, d * k].join(" ") + " 0 0)";
  };

  return transform.zoomFraction(0);
};
