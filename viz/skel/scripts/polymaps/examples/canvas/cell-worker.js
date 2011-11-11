onmessage = function(e) {
  var z0 = Math.max(0, 4 - e.data.zoom),
      z1 = Math.max(0, e.data.zoom - 4),
      w = e.data.size.x >> z0,
      h = e.data.size.y >> z0,
      n = 1 << z0,
      col = e.data.column >> z1 << z0,
      row = e.data.row >> z1 << z0,
      data = e.data.data = [],
      state = [];

  for (var j = 0, y = 0; j < n; j++, y += h) {
    for (var i = 0, x = 0; i < n; i++, x += w) {
      draw((j | row) | ((i | col) << 4), x, y);
    }
  }

  function draw(r, x, y) {
    for (var i = 0; i < w; i++) {
      state[i] = ~~(Math.random() * 2);
    }
    for (var j = 0; j < h; j++) {
      var p = state.slice(),
          k = 4 * (e.data.size.x * (j + y) + x);
      for (var i = 0; i < w; i++) {
        data[k++] = data[k++] = data[k++] = 255 * state[i];
        data[k++] = 255;
        state[i] = (r >> (p[i - 1] << 2 | p[i] << 1 | p[i + 1])) & 1;
      }
    }
  }

  postMessage(e.data);
};
