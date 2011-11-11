(function() {
  var po = org.polymaps;

  po.procedural = function() {
    var procedural = po.layer(load),
        manager,
        worker;

    procedural.worker = function(x) {
      if (!arguments.length) return worker;
      worker = x;
      manager = _manager(x);
      return procedural;
    };

    function load(tile) {
      if (tile.column < 0 || tile.column >= (1 << tile.zoom)) {
        tile.element = po.svg("g");
        return; // no wrap
      }

      var size = procedural.map().tileSize(),
          o = tile.element = po.svg("foreignObject"),
          c = o.appendChild(document.createElement("canvas")),
          w = size.x,
          h = size.y;

      o.setAttribute("width", w);
      o.setAttribute("height", h);
      c.setAttribute("width", w);
      c.setAttribute("height", h);

      tile.request = manager.work({
        row: tile.row,
        column: tile.column,
        zoom: tile.zoom,
        size: size
      }, callback);

      function callback(e) {
        var g = c.getContext("2d"),
            d = g.createImageData(w, h);
        tile.ready = true;
        procedural.dispatch({type: "load", tile: tile});
        for (var i = 0, n = w * h * 4; i < n; i++) d.data[i] = e.data[i];
        g.putImageData(d, 0, 0);
      }
    }

    return procedural;
  };

  // like po.queue, but for workers!
  function _manager(src) {
    var queue = {},
        queued = [],
        active = 0,
        size = 6,
        nextId = 0,
        callbacks = {},
        worker = new Worker(src);

    function process() {
      if ((active >= size) || !queued.length) return;
      active++;
      queued.pop()();
    }

    function dequeue(send) {
      for (var i = 0; i < queued.length; i++) {
        if (queued[i] == send) {
          queued.splice(i, 1);
          return true;
        }
      }
      return false;
    }

    worker.onmessage = function(e) {
      var id = e.data.id;
      active--;
      process();
      callbacks[id](e.data);
      delete callbacks[id];
    };

    queue.work = function(data, callback) {

      function send() {
        callbacks[data.id = nextId++] = callback;
        worker.postMessage(data);
      }

      function abort() {
        return dequeue(send);
      }

      queued.push(send);
      process();
      return {abort: abort};
    };

    return queue;
  }

})();
